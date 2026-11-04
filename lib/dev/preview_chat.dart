import 'dart:async';
import '../core/services/chat_realtime.dart';
import '../core/network/api_exception.dart';
import '../data/models/chat_models.dart';

/// Dữ liệu chat trong RAM cho bản xem trước; không gọi backend thật.
class PreviewChat {
  late final realtime = PreviewChatRealtime(this);
  static const unhandled = Object();
  final Map<String, dynamic> Function(int) person;
  final Map<String, dynamic> me;
  final bool Function(int) isBlocked;
  final Map<int, int> peers = {1: 2, 2: 4};
  final Map<int, List<Map<String, dynamic>>> messages = {};
  int nextMessageId = 100;

  PreviewChat({
    required this.person,
    required this.me,
    required this.isBlocked,
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
  }

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
      'media_urls': mediaUrls,
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
      var id = peers.entries.where((e) => e.value == peerId).firstOrNull?.key;
      if (id == null) {
        id = peers.length + 1;
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
  ChatConnection _connection = ChatConnection.disconnected;
  PreviewChatRealtime(this.backend);
  @override
  ChatConnection get connection => _connection;
  @override
  Stream<ChatEvent> get events => _events.stream;
  @override
  Stream<ChatConnection> get connections => _connections.stream;
  void _set(ChatConnection value) {
    _connection = value;
    _connections.add(value);
  }

  @override
  Future<void> acquire() async {
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
    final message = backend.append(
      conversationId,
      1,
      content,
      messageType,
      mediaUrls,
    );
    _events.add(
      ChatEvent(
        ChatEventKind.message,
        conversationId: conversationId,
        message: message,
      ),
    );
    _timers.add(
      Timer(const Duration(milliseconds: 500), () {
        if (backend.isBlocked(peer)) return;
        _events.add(
          ChatEvent(
            ChatEventKind.typing,
            conversationId: conversationId,
            userId: peer,
            isTyping: true,
          ),
        );
      }),
    );
    _timers.add(
      Timer(const Duration(milliseconds: 1200), () {
        if (backend.isBlocked(peer)) return;
        final reply = backend.append(
          conversationId,
          peer,
          'Mình nhận được rồi nhé!',
          'TEXT',
          [],
        );
        _events.add(
          ChatEvent(
            ChatEventKind.message,
            conversationId: conversationId,
            message: reply,
          ),
        );
        _events.add(
          ChatEvent(
            ChatEventKind.read,
            conversationId: conversationId,
            userId: peer,
            readMessageId: message.messageId,
          ),
        );
      }),
    );
  }

  @override
  void read(int conversationId, int messageId) {}
  @override
  void typing(int conversationId, bool value) {}
  @override
  void Function() watchTyping(int conversationId) => () {};
  @override
  Future<void> dispose() async {
    disconnect();
    await _events.close();
    await _connections.close();
  }
}
