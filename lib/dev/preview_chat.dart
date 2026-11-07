import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/chat_realtime.dart';
import '../core/network/api_exception.dart';
import '../core/services/blocked_users.dart';
import '../data/models/chat_models.dart';

/// Chat preview lưu trên máy khi có [preferences], không gọi backend thật.
class PreviewChat {
  late final realtime = PreviewChatRealtime(this);
  static const unhandled = Object();
  final Map<String, dynamic> Function(int) person;
  final Map<String, dynamic> me;
  final bool Function(int) isBlocked;
  final SharedPreferences? preferences;
  Future<void> _pending = Future<void>.value();
  String get _storageKey => 'preview_chat_v1_${me['user_id']}';
  final Map<int, int> peers = {1: 2, 2: 4};
  final Map<int, List<Map<String, dynamic>>> messages = {};
  int nextMessageId = 100;

  PreviewChat({
    required this.person,
    required this.me,
    required this.isBlocked,
    this.preferences,
  }) {
    for (final id in peers.keys) {
      messages[id] = [
        for (var i = 0; i < 25; i++)
          {
            'message_id': id * 100 + i,
            'conversation_id': id,
            'sender_id': i.isEven ? peers[id] : 1,
            'sender_name': i.isEven
                ? person(peers[id]!)['full_name']
                : me['full_name'],
            'content': i == 24
                ? 'Hẹn bạn buổi học tiếp theo nhé!'
                : 'Tin nhắn trao đổi bài học ${i + 1}',
            'message_type': 'TEXT',
            'media_urls': <String>[],
            'created_at': DateTime.now()
                .subtract(Duration(minutes: 26 - i))
                .toUtc()
                .toIso8601String(),
            'revoked': false,
          },
      ];
    }
    nextMessageId = 300;
    _restore();
  }

  Map<String, dynamic> _snapshot() => {
    'version': 1,
    'owner_id': me['user_id'],
    'next_message_id': nextMessageId,
    'conversations': [
      for (final entry in peers.entries)
        {
          'conversation_id': entry.key,
          'peer_id': entry.value,
          'messages': messages[entry.key] ?? <Map<String, dynamic>>[],
        },
    ],
  };

  bool _applySnapshot(dynamic data) {
    if (data is! Map<String, dynamic> ||
        data['version'] != 1 ||
        data['owner_id'] != me['user_id'] ||
        data['conversations'] is! List) {
      return false;
    }
    final restoredPeers = <int, int>{};
    final restoredMessages = <int, List<Map<String, dynamic>>>{};
    final messageIds = <int>{};
    final peerIds = <int>{};
    var nextId = 300;
    for (final row in data['conversations'] as List) {
      if (row is! Map<String, dynamic>) return false;
      final id = row['conversation_id'];
      final peer = row['peer_id'];
      if (id is! int ||
          id <= 0 ||
          restoredPeers.containsKey(id) ||
          peer is! int ||
          peer <= 0 ||
          peer == me['user_id'] ||
          !peerIds.add(peer) ||
          row['messages'] is! List) {
        return false;
      }
      final rows = <Map<String, dynamic>>[];
      for (final message in row['messages'] as List) {
        if (message is! Map<String, dynamic>) return false;
        final messageId = message['message_id'];
        final sender = message['sender_id'];
        final media = message['media_urls'];
        if (messageId is! int ||
            messageId <= 0 ||
            !messageIds.add(messageId) ||
            message['conversation_id'] != id ||
            (sender != me['user_id'] && sender != peer) ||
            message['content'] is! String ||
            message['sender_name'] is! String ||
            message['message_type'] is! String ||
            media is! List ||
            media.any((m) => m is! String) ||
            message['created_at'] is! String ||
            DateTime.tryParse(message['created_at'] as String) == null ||
            (message['revoked'] != null && message['revoked'] is! bool)) {
          return false;
        }
        rows.add({...message, 'media_urls': List<String>.from(media)});
        if (messageId >= nextId) nextId = messageId + 1;
      }
      restoredPeers[id] = peer;
      restoredMessages[id] = rows;
    }
    final storedNext = data['next_message_id'];
    if (storedNext is int && storedNext > nextId) nextId = storedNext;
    peers
      ..clear()
      ..addAll(restoredPeers);
    messages
      ..clear()
      ..addAll(restoredMessages);
    nextMessageId = nextId;
    return true;
  }

  void _restore() {
    final raw = preferences?.get(_storageKey);
    if (raw is! String) return;
    try {
      _applySnapshot(jsonDecode(raw));
    } on FormatException {
      /* Dữ liệu hỏng: giữ bộ mẫu, không kẹt khởi động. */
    }
  }

  Future<T> _transaction<T>(T Function() action, {bool save = true}) async {
    final before = _pending;
    final done = Completer<void>();
    _pending = done.future;
    await before;
    try {
      final store = preferences;
      final previous = save && store != null ? jsonEncode(_snapshot()) : null;
      final result = action();
      if (previous != null) {
        try {
          if (!await store!.setString(_storageKey, jsonEncode(_snapshot()))) {
            throw StateError('Could not save preview chat');
          }
        } catch (_) {
          _applySnapshot(jsonDecode(previous));
          try {
            await store!.setString(_storageKey, previous);
          } catch (_) {}
          throw const ApiException(
            type: ApiErrorType.server,
            statusCode: 500,
            code: '1001',
            message:
                'Không thể lưu tin nhắn trên máy. Nội dung chưa được gửi; hãy thử lại.',
          );
        }
      }
      return result;
    } finally {
      done.complete();
    }
  }

  Future<void> flush() => _pending;

  static bool handles(String method, String path) =>
      (method == 'GET' &&
          (path == '/conversations' ||
              RegExp(
                r'^/conversations/\d+/(messages|members)$',
              ).hasMatch(path) ||
              RegExp(r'^/users/\d+/relationship-stats$').hasMatch(path))) ||
      (method == 'POST' && path == '/conversations/direct') ||
      (method == 'DELETE' && RegExp(r'^/messages/\d+$').hasMatch(path));

  Future<Object?> handle(
    String method,
    String path,
    Map<String, dynamic> query,
    Map<String, dynamic> body,
  ) => _transaction(
    () => route(method, path, query, body),
    save: method != 'GET',
  );

  Future<ChatMessage> appendSaved(
    int conversationId,
    int senderId,
    String content,
    String type,
    List<String> mediaUrls,
  ) => _transaction(() {
    final peer = peers[conversationId];
    if (peer == null) {
      throw const ApiException(
        type: ApiErrorType.notFound,
        statusCode: 404,
        message: 'Cuộc trò chuyện không còn tồn tại.',
      );
    }
    if (isBlocked(peer)) throw BlockedUsers.unavailable;
    return append(conversationId, senderId, content, type, mediaUrls);
  });

  Map<String, dynamic> _member(int id) => id == 1 ? me : person(id);

  ChatMessage append(
    int conversationId,
    int senderId,
    String content,
    String type,
    List<String> mediaUrls,
  ) {
    final message = <String, dynamic>{
      'message_id': nextMessageId++,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'sender_name': _member(senderId)['full_name'],
      'content': content,
      'message_type': type,
      'media_urls': List<String>.of(mediaUrls),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    messages.putIfAbsent(conversationId, () => []).add(message);
    return ChatMessage.fromJson(message);
  }

  Map<String, dynamic> _page(
    List<Map<String, dynamic>> all,
    Map<String, dynamic> query, {
    String key = 'items',
  }) {
    final after = int.tryParse('${query['after']}') ?? 0;
    final limit = int.tryParse('${query['limit']}') ?? 20;
    final items = all.skip(after).take(limit).toList();
    final end = after + items.length;
    return {
      key: items,
      'pagination': {
        'after': end < all.length ? end : null,
        'has_next': end < all.length,
      },
    };
  }

  Object? route(
    String method,
    String path,
    Map<String, dynamic> query,
    Map<String, dynamic> body,
  ) {
    final relationship = RegExp(
      r'^/users/(\d+)/relationship-stats$',
    ).firstMatch(path);
    if (relationship != null && method == 'GET') {
      final id = int.parse(relationship[1]!);
      return {
        'user_id': id,
        'counts': {
          'friends_count': 45,
          'followers_count': 9,
          'following_count': 12,
        },
        'relationship_with_me': {'blocked': isBlocked(id)},
      };
    }
    if (path == '/conversations' && method == 'GET') {
      final rows = [
        for (final entry in peers.entries)
          if (!isBlocked(entry.value))
            {
              'conversation_id': entry.key,
              'type': 'DIRECT',
              'display_name': person(entry.value)['full_name'],
              'display_avatar_url': person(entry.value)['avatar_url'],
              'last_message': messages[entry.key]?.lastOrNull,
              'unread_count': 0,
              'updated_at': messages[entry.key]?.lastOrNull?['created_at'],
            },
      ];
      rows.sort((a, b) => '${b['updated_at']}'.compareTo('${a['updated_at']}'));
      return _page(rows, query);
    }
    if (path == '/conversations/direct' && method == 'POST') {
      final peerId = int.parse('${body['target_user_id']}');
      if (peerId <= 0 || peerId == me['user_id']) {
        throw const ApiException(
          type: ApiErrorType.validation,
          statusCode: 400,
          message: 'Vui lòng chọn người khác để nhắn tin.',
        );
      }
      if (isBlocked(peerId)) throw BlockedUsers.unavailable;
      var id = peers.entries.where((e) => e.value == peerId).firstOrNull?.key;
      if (id == null) {
        id = peers.keys.fold(0, (a, b) => a > b ? a : b) + 1;
        peers[id] = peerId;
        messages[id] = [];
      }
      return {
        'conversation_id': id,
        'type': 'DIRECT',
        'members': [_member(1), _member(peerId)],
      };
    }
    final match = RegExp(
      r'^/conversations/(\d+)/(messages|members)$',
    ).firstMatch(path);
    if (match != null && method == 'GET') {
      final id = int.parse(match[1]!);
      final peer = peers[id];
      if (peer != null && isBlocked(peer)) throw BlockedUsers.unavailable;
      if (match[2] == 'members') return [_member(1), _member(peers[id]!)];
      return {
        'conversation_id': id,
        'conversation_type': 'DIRECT',
        ..._page(
          (messages[id] ?? []).reversed.toList(),
          query,
          key: 'messages',
        ),
      };
    }
    final deletion = RegExp(r'^/messages/(\d+)$').firstMatch(path);
    if (deletion != null && method == 'DELETE') {
      final id = int.parse(deletion[1]!);
      for (final list in messages.values) {
        if (body['scope'] == 'EVERYONE') {
          for (final m in list.where((m) => m['message_id'] == id)) {
            m['revoked'] = true;
            m['content'] = '';
            m['media_urls'] = <String>[];
          }
        } else {
          list.removeWhere((m) => m['message_id'] == id);
        }
      }
      return {'message_id': id, 'scope': body['scope']};
    }
    return unhandled;
  }
}

class PreviewChatRealtime implements ChatRealtime {
  final PreviewChat backend;
  final _events = StreamController<ChatEvent>.broadcast(sync: true);
  final _connections = StreamController<ChatConnection>.broadcast(sync: true);
  final _timers = <Timer>[];
  int _clients = 0;
  int _generation = 0;
  bool _disposed = false;
  ChatConnection _connection = ChatConnection.disconnected;
  PreviewChatRealtime(this.backend);
  @override
  ChatConnection get connection => _connection;
  @override
  Stream<ChatEvent> get events => _events.stream;
  @override
  Stream<ChatConnection> get connections => _connections.stream;
  void _set(ChatConnection value) {
    if (_disposed || _connection == value) return;
    _connection = value;
    _connections.add(value);
  }

  @override
  Future<void> acquire() async {
    if (_disposed) return;
    _clients++;
    _set(ChatConnection.connected);
  }

  @override
  void release() {
    if (_clients > 0) _clients--;
    if (_clients == 0) pause();
  }

  @override
  void pause() {
    _generation++;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _set(ChatConnection.disconnected);
  }

  @override
  Future<void> resume() async {
    if (_clients > 0) _set(ChatConnection.connected);
  }

  @override
  Future<void> reconnect() => resume();
  @override
  void disconnect() {
    _clients = 0;
    pause();
  }

  @override
  void send({
    required int conversationId,
    required String content,
    String messageType = 'TEXT',
    List<String> mediaUrls = const [],
  }) {
    if (connection != ChatConnection.connected) {
      throw const ApiException(
        type: ApiErrorType.noConnection,
        message: 'Chưa kết nối tin nhắn.',
      );
    }
    final peer = backend.peers[conversationId]!;
    if (backend.isBlocked(peer)) {
      throw const ApiException(
        type: ApiErrorType.forbidden,
        code: 'USER_BLOCKED',
        message: 'Bạn đã chặn người này.',
      );
    }
    unawaited(
      _sendSaved(
        conversationId,
        peer,
        content,
        messageType,
        mediaUrls,
        _generation,
      ),
    );
  }

  bool _current(int generation, int peer) =>
      !_disposed && generation == _generation && !backend.isBlocked(peer);

  Future<void> _sendSaved(
    int id,
    int peer,
    String content,
    String type,
    List<String> media,
    int generation,
  ) async {
    try {
      final message = await backend.appendSaved(id, 1, content, type, media);
      // Echo là xác nhận gửi: chỉ phát sau khi dữ liệu đã ghi thành công.
      if (!_current(generation, peer)) return;
      _events.add(
        ChatEvent(ChatEventKind.message, conversationId: id, message: message),
      );
      _timers.add(
        Timer(const Duration(milliseconds: 500), () {
          if (_current(generation, peer)) {
            _events.add(
              ChatEvent(
                ChatEventKind.typing,
                conversationId: id,
                userId: peer,
                isTyping: true,
              ),
            );
          }
        }),
      );
      _timers.add(
        Timer(const Duration(milliseconds: 1200), () {
          if (_current(generation, peer)) {
            unawaited(_reply(id, peer, message.messageId, generation));
          }
        }),
      );
    } on ApiException catch (e) {
      if (!_disposed && generation == _generation) {
        _events.add(
          ChatEvent(ChatEventKind.error, conversationId: id, error: e),
        );
      }
    }
  }

  Future<void> _reply(int id, int peer, int readId, int generation) async {
    try {
      final reply = await backend.appendSaved(
        id,
        peer,
        'Mình nhận được rồi nhé!',
        'TEXT',
        [],
      );
      if (!_current(generation, peer)) return;
      _events.add(
        ChatEvent(ChatEventKind.message, conversationId: id, message: reply),
      );
      _events.add(
        ChatEvent(
          ChatEventKind.read,
          conversationId: id,
          userId: peer,
          readMessageId: readId,
        ),
      );
    } on ApiException catch (e) {
      if (_current(generation, peer)) {
        _events.add(
          ChatEvent(ChatEventKind.error, conversationId: id, error: e),
        );
      }
    }
  }

  @override
  void read(int conversationId, int messageId) {}
  @override
  void typing(int conversationId, bool value) {}
  @override
  void Function() watchTyping(int conversationId) => () {};
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    disconnect();
    _disposed = true;
    if (backend.preferences != null) await backend.flush();
    await _events.close();
    await _connections.close();
  }
}
