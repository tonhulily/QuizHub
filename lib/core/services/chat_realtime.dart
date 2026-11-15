import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../data/models/chat_models.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../network/api_exception.dart';
import '../network/response_codes.dart';
import '../network/session_events.dart';
import '../storage/token_storage.dart';
import '../utils/json_utils.dart';

enum ChatConnection { disconnected, connecting, connected }

enum ChatEventKind { message, read, typing, sync, error }

class ChatEvent {
  final ChatEventKind kind;
  final int conversationId;
  final ChatMessage? message;
  final int userId;
  final int readMessageId;
  final bool isTyping;
  final ApiException? error;

  const ChatEvent(
    this.kind, {
    this.conversationId = 0,
    this.message,
    this.userId = 0,
    this.readMessageId = 0,
    this.isTyping = false,
    this.error,
  });

  factory ChatEvent.fromJson(Map<String, dynamic> root) {
    final data = J.asMap(root['data'] ?? root['payload']) ?? root;
    final conversationId = J.intOr(data['conversation_id']);
    final type = J
        .stringOr(
          root['event_type'] ??
              root['type'] ??
              data['event_type'] ??
              data['type'],
        )
        .toUpperCase();
    if ((root['code'] != null &&
            !ResponseCodes.isSuccess(root['code'].toString())) ||
        type.contains('ERROR')) {
      return ChatEvent(
        ChatEventKind.error,
        conversationId: conversationId,
        error: ApiException(
          type: ApiErrorType.business,
          code: J.asString(root['code']),
          message: J.stringOr(
            root['message'] ?? data['message'],
            'Không thể thực hiện thao tác chat.',
          ),
        ),
      );
    }
    if (data['is_typing'] != null) {
      return ChatEvent(
        ChatEventKind.typing,
        conversationId: conversationId,
        userId: J.intOr(data['user_id'] ?? data['sender_id']),
        isTyping: J.asBool(data['is_typing']),
      );
    }
    if (type.contains('READ') ||
        data['reader_id'] != null ||
        data['last_read_message_id'] != null) {
      return ChatEvent(
        ChatEventKind.read,
        conversationId: conversationId,
        userId: J.intOr(data['reader_id'] ?? data['user_id']),
        readMessageId: J.intOr(
          data['last_read_message_id'] ?? data['message_id'],
        ),
      );
    }
    final message = J.asMap(data['message']) ?? data;
    if (message['message_id'] != null && message['sender_id'] != null) {
      final parsed = ChatMessage.fromJson(
        message,
        conversationId: conversationId,
      );
      return ChatEvent(
        ChatEventKind.message,
        conversationId: parsed.conversationId,
        message: parsed,
      );
    }
    // Sự kiện hệ thống/thu hồi chưa có schema: đồng bộ lại từ REST.
    return ChatEvent(ChatEventKind.sync, conversationId: conversationId);
  }
}

abstract class ChatRealtime {
  ChatConnection get connection;
  Stream<ChatConnection> get connections;
  Stream<ChatEvent> get events;
  Future<void> acquire();
  void release();
  void pause();
  Future<void> resume();
  Future<void> reconnect();
  void disconnect();
  void send({
    required int conversationId,
    required String content,
    String messageType = 'TEXT',
    List<String> mediaUrls = const [],
  });
  void read(int conversationId, int messageId);
  void typing(int conversationId, bool value);
  void Function() watchTyping(int conversationId);
  Future<void> dispose();
}

class StompChatRealtime implements ChatRealtime {
  final ApiClient _api;
  final TokenStorage _tokens;
  final String url;
  final Duration retryBase;
  late final StreamSubscription<void> _sessionSub;
  final _connections = StreamController<ChatConnection>.broadcast(sync: true);
  final _events = StreamController<ChatEvent>.broadcast(sync: true);
  final _typingCounts = <int, int>{};
  final _typingSubscriptions = <int, StompUnsubscribe>{};
  StompClient? _client;
  Timer? _retry;
  int _clients = 0;
  int _generation = 0;
  int _attempt = 0;
  bool _paused = false;
  bool _disposed = false;
  ChatConnection _connection = ChatConnection.disconnected;

  StompChatRealtime(
    this._api,
    this._tokens,
    SessionEvents sessions, {
    this.url = AppConfig.wsUrl,
    this.retryBase = const Duration(seconds: 1),
  }) {
    _sessionSub = sessions.onSessionExpired.listen((_) => disconnect());
  }

  @override
  ChatConnection get connection => _connection;
  @override
  Stream<ChatConnection> get connections => _connections.stream;
  @override
  Stream<ChatEvent> get events => _events.stream;

  void _setConnection(ChatConnection value) {
    if (_disposed || _connection == value) return;
    _connection = value;
    _connections.add(value);
  }

  @override
  Future<void> acquire() async {
    if (_disposed) return;
    _clients++;
    _paused = false;
    await _connect();
  }

  @override
  void release() {
    if (_clients > 0) _clients--;
    if (_clients == 0) _drop();
  }

  @override
  void pause() {
    _paused = true;
    _drop();
  }

  @override
  Future<void> resume() async {
    _paused = false;
    await _connect();
  }

  @override
  Future<void> reconnect() async {
    _drop();
    _paused = false;
    await _connect();
  }

  @override
  void disconnect() {
    _clients = 0;
    _paused = false;
    _typingCounts.clear();
    _drop();
  }

  void _drop() {
    _generation++;
    _retry?.cancel();
    _retry = null;
    final client = _client;
    _client = null;
    _typingSubscriptions.clear();
    try {
      client?.deactivate();
    } on StompBadStateException {
      // Socket có thể đóng giữa lúc kiểm tra connected và gửi DISCONNECT.
    }
    _setConnection(ChatConnection.disconnected);
  }

  Future<void> _connect() async {
    if (_disposed ||
        _paused ||
        _clients == 0 ||
        _connection != ChatConnection.disconnected) {
      return;
    }
    _retry?.cancel();
    _retry = null;
    final generation = ++_generation;
    _setConnection(ChatConnection.connecting);
    try {
      // Dùng luồng refresh sẵn có trước mỗi handshake; không sửa logic đăng nhập.
      await _api.getVoid(ApiEndpoints.me);
      if (generation != _generation || _disposed) return;
      final token = _tokens.accessToken;
      if (token == null || token.isEmpty) {
        disconnect();
        return;
      }
      _client = StompClient(
        config: StompConfig(
          url: url,
          reconnectDelay: Duration.zero,
          connectionTimeout: const Duration(seconds: 12),
          heartbeatIncoming: const Duration(seconds: 10),
          heartbeatOutgoing: const Duration(seconds: 10),
          stompConnectHeaders: {'Authorization': 'Bearer $token'},
          onConnect: (_) {
            if (generation != _generation || _client == null) return;
            _client!.subscribe(
              destination: '/user/queue/messages',
              callback: (frame) {
                if (generation == _generation) _receive(frame.body);
              },
            );
            for (final id in _typingCounts.keys) {
              _subscribeTyping(id);
            }
            _attempt = 0;
            _setConnection(ChatConnection.connected);
          },
          onStompError: (frame) {
            if (generation != _generation) return;
            _receive(frame.body, isError: true);
            _lost(generation);
          },
          onWebSocketError: (_) => scheduleMicrotask(() => _lost(generation)),
          onWebSocketDone: () => scheduleMicrotask(() => _lost(generation)),
          onDisconnect: (_) => _lost(generation),
        ),
      );
      _client!.activate();
    } on ApiException catch (error) {
      if (generation != _generation) return;
      if (error.isUnauthorized) {
        disconnect();
      } else {
        _lost(generation);
      }
    } catch (_) {
      _lost(generation);
    }
  }

  void _lost(int generation) {
    if (generation != _generation || _disposed) return;
    _drop();
    if (_clients == 0 || _paused) return;
    final delay = retryBase * (1 << _attempt.clamp(0, 5));
    _attempt++;
    _retry = Timer(delay, _connect);
  }

  void _receive(String? body, {bool isError = false}) {
    if (_disposed || body == null) return;
    try {
      final json = J.asMap(jsonDecode(body));
      if (json != null) {
        _events.add(
          ChatEvent.fromJson(isError ? {...json, 'event_type': 'ERROR'} : json),
        );
      }
    } catch (_) {
      if (isError) {
        _events.add(
          const ChatEvent(
            ChatEventKind.error,
            error: ApiException(
              type: ApiErrorType.business,
              message:
                  'Máy chủ từ chối thao tác chat. Hãy làm mới cuộc trò chuyện.',
            ),
          ),
        );
      }
    }
  }

  void _publish(String destination, Map<String, dynamic> data) {
    if (_client?.connected != true) {
      throw const ApiException(
        type: ApiErrorType.noConnection,
        message: 'Chưa kết nối được tin nhắn. Hãy thử lại sau.',
      );
    }
    try {
      _client!.send(
        destination: destination,
        headers: {'content-type': 'application/json'},
        body: jsonEncode(data),
      );
    } on StompBadStateException {
      _lost(_generation);
      throw const ApiException(
        type: ApiErrorType.noConnection,
        message: 'Kết nối tin nhắn vừa bị ngắt. Hãy thử lại sau.',
      );
    }
  }

  @override
  void send({
    required int conversationId,
    required String content,
    String messageType = 'TEXT',
    List<String> mediaUrls = const [],
  }) => _publish('/app/chat.send', {
    'conversation_id': conversationId,
    'content': content,
    'message_type': messageType,
    'media_urls': mediaUrls,
  });
  @override
  void read(int conversationId, int messageId) {
    if (connection == ChatConnection.connected) {
      try {
        _publish('/app/chat.read', {
          'conversation_id': conversationId,
          'message_id': messageId,
        });
      } on ApiException {
        /* Đồng bộ lại khi kết nối phục hồi. */
      }
    }
  }

  @override
  void typing(int conversationId, bool value) {
    if (connection == ChatConnection.connected) {
      try {
        _publish('/app/chat.typing', {
          'conversation_id': conversationId,
          'is_typing': value,
        });
      } on ApiException {
        /* Typing không cần gửi bù. */
      }
    }
  }

  void _subscribeTyping(int id) {
    if (_client?.connected != true || _typingSubscriptions.containsKey(id)) {
      return;
    }
    final generation = _generation;
    _typingSubscriptions[id] = _client!.subscribe(
      destination: '/topic/conv.$id.typing',
      callback: (f) {
        if (generation == _generation) _receive(f.body);
      },
    );
  }

  @override
  void Function() watchTyping(int conversationId) {
    _typingCounts.update(conversationId, (n) => n + 1, ifAbsent: () => 1);
    _subscribeTyping(conversationId);
    var released = false;
    return () {
      if (released) return;
      released = true;
      final remaining = (_typingCounts[conversationId] ?? 1) - 1;
      if (remaining > 0) {
        _typingCounts[conversationId] = remaining;
        return;
      }
      _typingCounts.remove(conversationId);
      final unsubscribe = _typingSubscriptions.remove(conversationId);
      if (_client?.connected == true) unsubscribe?.call();
    };
  }

  @override
  Future<void> dispose() async {
    disconnect();
    _disposed = true;
    await _sessionSub.cancel();
    await _connections.close();
    await _events.close();
  }
}
