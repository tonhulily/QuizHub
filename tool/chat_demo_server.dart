import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Mock API dùng chung cho hai phiên FE trên máy phát triển.
/// Chạy: dart run tool/chat_demo_server.dart --port=8787
/// Không dùng tài khoản hay server production; không có phản hồi tự động.
class ChatDemoServer {
  final HttpServer _http;
  final Directory dataDirectory;
  final Map<int, Map<String, dynamic>> _conversations = {};
  final Map<int, Set<int>> _blocks = {1: {}, 2: {}};
  final Set<_StompPeer> _peers = {};
  Future<void> _pending = Future<void>.value();
  int _nextConversationId = 1;
  int _nextMessageId = 1;
  int _frameId = 1;
  bool _closing = false;

  ChatDemoServer._(this._http, this.dataDirectory);

  int get port => _http.port;
  String get baseUrl => 'http://127.0.0.1:$port/api/v1';
  String get websocketUrl => 'ws://127.0.0.1:$port/api/v1/ws/websocket';
  File get _store => File('${dataDirectory.path}/state.json');

  static Future<ChatDemoServer> start({
    required Directory dataDirectory,
    InternetAddress? address,
    int port = 0,
  }) async {
    await dataDirectory.create(recursive: true);
    final http = await HttpServer.bind(
      address ?? InternetAddress.loopbackIPv4,
      port,
    );
    final server = ChatDemoServer._(http, dataDirectory);
    try {
      if (await server._store.exists()) {
        server._restore(jsonDecode(await server._store.readAsString()));
      } else {
        server._createConversation(1, 2);
        await server._save();
      }
    } catch (_) {
      await http.close(force: true);
      rethrow;
    }
    http.listen((request) => unawaited(server._handle(request)));
    return server;
  }

  static Map<String, dynamic> user(int id) {
    if (id != 1 && id != 2) {
      throw const _DemoError(404, '1004', 'Không có tài khoản thử này.');
    }
    return {
      'user_id': id,
      'full_name': id == 1 ? 'Nguyễn Văn An' : 'Trần Thị Lan',
      'email': id == 1 ? 'an@quizhub.test' : 'lan@quizhub.test',
      'avatar_url': 'https://i.pravatar.cc/150?img=${id == 1 ? 12 : 47}',
      'student_lecturer_code': id == 1 ? '20210001' : '20210002',
      'role': 'STUDENT',
      'profile_completed': true,
      'verified': true,
      'bio': 'Tài khoản thử chat hai chiều',
      'friends_count': 1,
      'followers_count': 0,
      'following_count': 0,
      'created_at': '2026-01-01T00:00:00Z',
    };
  }

  static int? _identity(String? authorization) {
    final token = authorization?.replaceFirst(
      RegExp(r'^Bearer\s+', caseSensitive: false),
      '',
    );
    return switch (token) {
      'chat-demo-1' => 1,
      'chat-demo-2' => 2,
      _ => null,
    };
  }

  Map<String, dynamic> _snapshot() => {
    'version': 1,
    'next_conversation_id': _nextConversationId,
    'next_message_id': _nextMessageId,
    'blocks': {
      for (final entry in _blocks.entries) '${entry.key}': entry.value.toList(),
    },
    'conversations': _conversations.values.toList(),
  };

  void _restore(dynamic raw) {
    if (raw is! Map<String, dynamic> ||
        raw['version'] != 1 ||
        raw['conversations'] is! List ||
        raw['blocks'] is! Map) {
      throw const FormatException(
        'Dữ liệu chat demo không hợp lệ; file cũ được giữ nguyên.',
      );
    }
    final conversations = <int, Map<String, dynamic>>{};
    final ids = <int>{};
    var nextConversation = 1;
    var nextMessage = 1;
    for (final row in raw['conversations'] as List) {
      if (row is! Map<String, dynamic>) {
        throw const FormatException('Hội thoại không hợp lệ.');
      }
      final id = row['conversation_id'];
      final members = row['members'];
      if (id is! int ||
          id <= 0 ||
          conversations.containsKey(id) ||
          members is! List ||
          members.length != 2 ||
          members.toSet().length != 2 ||
          members.any((m) => m != 1 && m != 2) ||
          row['messages'] is! List ||
          row['reads'] is! Map ||
          row['created_at'] is! String) {
        throw const FormatException('Hội thoại không hợp lệ.');
      }
      for (final message in row['messages'] as List) {
        if (message is! Map<String, dynamic> ||
            message['message_id'] is! int ||
            (message['message_id'] as int) <= 0 ||
            !ids.add(message['message_id'] as int) ||
            message['conversation_id'] != id ||
            !members.contains(message['sender_id']) ||
            message['content'] is! String ||
            message['media_urls'] is! List ||
            (message['media_urls'] as List).any((m) => m is! String) ||
            message['created_at'] is! String ||
            DateTime.tryParse(message['created_at'] as String) == null ||
            message['deleted_for'] is! List ||
            message['revoked'] is! bool) {
          throw const FormatException('Tin nhắn không hợp lệ.');
        }
        nextMessage = max(nextMessage, (message['message_id'] as int) + 1);
      }
      conversations[id] = row;
      nextConversation = max(nextConversation, id + 1);
    }
    final blocks = raw['blocks'] as Map;
    for (final id in [1, 2]) {
      final values = blocks['$id'];
      if (values is! List || values.any((v) => v != 1 && v != 2)) {
        throw const FormatException('Danh sách chặn không hợp lệ.');
      }
    }
    _conversations
      ..clear()
      ..addAll(conversations);
    for (final id in [1, 2]) {
      _blocks[id] = Set<int>.from(blocks['$id'] as List)..remove(id);
    }
    _nextConversationId = max(
      nextConversation,
      raw['next_conversation_id'] is int
          ? raw['next_conversation_id'] as int
          : 1,
    );
    _nextMessageId = max(
      nextMessage,
      raw['next_message_id'] is int ? raw['next_message_id'] as int : 1,
    );
  }

  Future<void> _save() async {
    final temporary = File('${_store.path}.tmp');
    await temporary.writeAsString(jsonEncode(_snapshot()), flush: true);
    await temporary.rename(_store.path);
  }

  Future<T> _serial<T>(
    FutureOr<T> Function() action, {
    bool save = false,
  }) async {
    final before = _pending;
    final done = Completer<void>();
    _pending = done.future;
    await before;
    final previous = save ? jsonEncode(_snapshot()) : null;
    try {
      final result = await action();
      if (save) {
        try {
          await _save();
        } catch (_) {
          throw const _DemoError(
            500,
            '1001',
            'Không thể lưu tin nhắn trên máy chủ thử. Hãy thử lại.',
          );
        }
      }
      return result;
    } catch (_) {
      if (previous != null) _restore(jsonDecode(previous));
      rethrow;
    } finally {
      done.complete();
    }
  }

  bool _blocked(int a, int b) =>
      _blocks[a]!.contains(b) || _blocks[b]!.contains(a);

  int _other(Map<String, dynamic> conversation, int id) =>
      (conversation['members'] as List).cast<int>().firstWhere((m) => m != id);

  Map<String, dynamic> _conversation(int id, int owner, {bool visible = true}) {
    final c = _conversations[id];
    if (c == null) {
      throw const _DemoError(404, '1004', 'Không tìm thấy cuộc trò chuyện.');
    }
    if (!(c['members'] as List).contains(owner)) {
      throw const _DemoError(
        403,
        '1009',
        'Không có quyền xem cuộc trò chuyện.',
      );
    }
    if (visible && _blocked(owner, _other(c, owner))) {
      throw const _DemoError(
        403,
        'USER_BLOCKED',
        'Cuộc trò chuyện không khả dụng khi một trong hai người chặn người còn lại.',
      );
    }
    return c;
  }

  Map<String, dynamic> _createConversation(int owner, int target) {
    user(target);
    if (owner == target) {
      throw const _DemoError(400, '1002', 'Hãy chọn tài khoản còn lại.');
    }
    if (_blocked(owner, target)) {
      throw const _DemoError(
        403,
        'USER_BLOCKED',
        'Không thể nhắn tin khi đang chặn nhau.',
      );
    }
    for (final c in _conversations.values) {
      final members = c['members'] as List;
      if (members.contains(owner) && members.contains(target)) return c;
    }
    final id = _nextConversationId++;
    final c = <String, dynamic>{
      'conversation_id': id,
      'members': [owner, target],
      'messages': <Map<String, dynamic>>[],
      'reads': {'$owner': 0, '$target': 0},
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    _conversations[id] = c;
    return c;
  }

  List<Map<String, dynamic>> _messages(Map<String, dynamic> c, int owner) =>
      (c['messages'] as List)
          .cast<Map<String, dynamic>>()
          .where((m) => !(m['deleted_for'] as List).contains(owner))
          .toList();

  String _mediaUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null &&
        ['localhost', '127.0.0.1'].contains(uri.host) &&
        RegExp(
          r'^/api/v1/media/[a-f0-9]{32}\.(jpg|png|webp)$',
        ).hasMatch(uri.path)) {
      return 'http://127.0.0.1:$port${uri.path}';
    }
    return value;
  }

  Map<String, dynamic> _publicMessage(Map<String, dynamic> m) => {
    'message_id': m['message_id'],
    'conversation_id': m['conversation_id'],
    'sender_id': m['sender_id'],
    'sender_name': user(m['sender_id'] as int)['full_name'],
    'avatar_url': user(m['sender_id'] as int)['avatar_url'],
    'message_type': m['message_type'],
    'created_at': m['created_at'],
    'revoked': m['revoked'],
    'content': m['revoked'] == true ? '' : m['content'],
    'media_urls': m['revoked'] == true
        ? <String>[]
        : (m['media_urls'] as List).cast<String>().map(_mediaUrl).toList(),
  };

  Map<String, dynamic> _summary(Map<String, dynamic> c, int owner) {
    final peer = user(_other(c, owner));
    final messages = _messages(c, owner);
    final read = (c['reads'] as Map)['$owner'] as int? ?? 0;
    return {
      'conversation_id': c['conversation_id'],
      'type': 'DIRECT',
      'members': (c['members'] as List).cast<int>().map(user).toList(),
      'display_name': peer['full_name'],
      'display_avatar_url': peer['avatar_url'],
      'last_message': messages.isEmpty ? null : _publicMessage(messages.last),
      'updated_at': messages.isEmpty
          ? c['created_at']
          : messages.last['created_at'],
      'unread_count': messages
          .where(
            (m) =>
                m['sender_id'] != owner &&
                (m['message_id'] as int) > read &&
                m['revoked'] != true,
          )
          .length,
    };
  }

  Map<String, dynamic> _page(
    List<dynamic> rows,
    Uri uri, {
    String key = 'items',
  }) {
    final offset = int.tryParse(uri.queryParameters['after'] ?? '') ?? 0;
    final limit = (int.tryParse(uri.queryParameters['limit'] ?? '') ?? 20)
        .clamp(1, 50);
    if (offset < 0) {
      throw const _DemoError(400, '1002', 'Con trỏ phân trang không hợp lệ.');
    }
    final items = rows.skip(offset).take(limit).toList();
    final end = offset + items.length;
    return {
      key: items,
      'pagination': {
        'after': end < rows.length ? '$end' : null,
        'has_next': end < rows.length,
      },
    };
  }

  void _cors(HttpResponse response) {
    response.headers.set('access-control-allow-origin', '*');
    response.headers.set(
      'access-control-allow-methods',
      'GET,POST,PUT,DELETE,OPTIONS',
    );
    response.headers.set(
      'access-control-allow-headers',
      'authorization,content-type,accept,x-requested-with',
    );
    response.headers.set(
      'access-control-expose-headers',
      'content-type,content-length',
    );
  }

  Future<void> _json(
    HttpResponse response,
    dynamic data, {
    _DemoError? error,
  }) async {
    response.statusCode = error?.status ?? 200;
    response.headers.contentType = ContentType.json;
    response.write(
      jsonEncode({
        'code': error?.code ?? '0000',
        'message': error?.message ?? 'OK',
        'data': data,
      }),
    );
    await response.close();
  }

  Future<Uint8List> _bytes(
    HttpRequest request, {
    int limit = 128 * 1024,
  }) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in request) {
      if (bytes.length + chunk.length > limit) {
        throw const _DemoError(
          413,
          '1003',
          'Dữ liệu vượt dung lượng cho phép.',
        );
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  Future<Map<String, dynamic>> _body(HttpRequest request) async {
    final bytes = await _bytes(request);
    if (bytes.isEmpty) return {};
    final data = jsonDecode(utf8.decode(bytes));
    if (data is! Map<String, dynamic>) {
      throw const _DemoError(400, '1002', 'Body phải là JSON object.');
    }
    return data;
  }

  Future<void> _handle(HttpRequest request) async {
    _cors(request.response);
    try {
      if (_closing) {
        throw const _DemoError(503, '1001', 'Server thử đang dừng.');
      }
      if (request.method == 'OPTIONS') {
        request.response.statusCode = 204;
        await request.response.close();
        return;
      }
      final path = request.uri.path;
      if (path == '/health' || path == '/api/v1/health') {
        await _json(request.response, {
          'service': 'quizhub-chat-demo',
          'users': [1, 2],
        });
        return;
      }
      if (path == '/api/v1/ws/websocket') {
        if (!WebSocketTransformer.isUpgradeRequest(request)) {
          throw const _DemoError(400, '1002', 'Cần WebSocket upgrade.');
        }
        final socket = await WebSocketTransformer.upgrade(request);
        final peer = _StompPeer(this, socket);
        _peers.add(peer);
        peer.listen();
        return;
      }
      if (request.method == 'GET' && path.startsWith('/api/v1/media/')) {
        await _serveMedia(request);
        return;
      }
      if (path == '/api/v1/auth/login' && request.method == 'POST') {
        final body = await _body(request);
        final owner = body['email'] == 'an@quizhub.test'
            ? 1
            : body['email'] == 'lan@quizhub.test'
            ? 2
            : null;
        if (owner == null || body['password'] != 'Demo1234') {
          throw const _DemoError(401, '1006', 'Tài khoản thử không đúng.');
        }
        await _json(request.response, _session(owner));
        return;
      }
      if (path == '/api/v1/auth/refresh-token' && request.method == 'POST') {
        final body = await _body(request);
        final token = '${body['refresh_token']}';
        final owner = token == 'chat-demo-refresh-1'
            ? 1
            : token == 'chat-demo-refresh-2'
            ? 2
            : null;
        if (owner == null) {
          throw const _DemoError(401, '1006', 'Phiên thử không đúng.');
        }
        await _json(request.response, _session(owner));
        return;
      }
      final owner = _identity(
        request.headers.value(HttpHeaders.authorizationHeader),
      );
      if (owner == null) {
        throw const _DemoError(401, '1006', 'Thiếu token tài khoản thử.');
      }
      if (path == '/api/v1/medias/upload' && request.method == 'POST') {
        await _json(request.response, await _upload(request));
        return;
      }
      final body = ['POST', 'PUT', 'DELETE'].contains(request.method)
          ? await _body(request)
          : <String, dynamic>{};
      final mutation =
          request.method != 'GET' ||
          RegExp(r'^/api/v1/conversations/\d+/messages$').hasMatch(path);
      final result = await _serial(
        () => _route(owner, request.method, request.uri, body),
        save: mutation,
      );
      await _json(request.response, result);
      if (RegExp(r'^/api/v1/conversations/\d+/messages$').hasMatch(path)) {
        final id = int.parse(path.split('/')[4]);
        final c = _conversations[id]!;
        _readEvent(c, owner);
      } else if (path.startsWith('/api/v1/blocks/') ||
          path.startsWith('/api/v1/messages/')) {
        _syncUsers({1, 2});
      }
    } on _DemoError catch (e) {
      await _json(request.response, null, error: e);
    } on FormatException {
      await _json(
        request.response,
        null,
        error: const _DemoError(400, '1002', 'Dữ liệu không đúng định dạng.'),
      );
    } catch (_) {
      await _json(
        request.response,
        null,
        error: const _DemoError(
          500,
          '1001',
          'Không thể xử lý yêu cầu ở mock chat.',
        ),
      );
    }
  }

  Map<String, dynamic> _session(int owner) => {
    ...user(owner),
    'username': user(owner)['full_name'],
    'access_token': 'chat-demo-$owner',
    'refresh_token': 'chat-demo-refresh-$owner',
  };

  dynamic _route(int owner, String method, Uri uri, Map<String, dynamic> body) {
    final path = uri.path.replaceFirst('/api/v1', '');
    if (path == '/users/me' && method == 'GET') return user(owner);
    if (path == '/auth/logout') return null;
    if (path == '/blocks' && method == 'GET') {
      return _page(_blocks[owner]!.map(user).toList(), uri);
    }
    final block = RegExp(r'^/blocks/(\d+)$').firstMatch(path);
    if (block != null && (method == 'POST' || method == 'DELETE')) {
      final target = int.parse(block[1]!);
      user(target);
      if (owner == target) {
        throw const _DemoError(400, '1002', 'Không thể chặn mình.');
      }
      if (method == 'POST') {
        _blocks[owner]!.add(target);
      } else {
        _blocks[owner]!.remove(target);
      }
      return null;
    }
    final stats = RegExp(r'^/users/(\d+)/relationship-stats$').firstMatch(path);
    if (stats != null && method == 'GET') {
      final target = int.parse(stats[1]!);
      user(target);
      return {
        'user_id': target,
        'counts': {
          'friends_count': 1,
          'followers_count': 0,
          'following_count': 0,
        },
        'relationship_with_me': {
          'blocked': owner != target && _blocked(owner, target),
        },
      };
    }
    final profile = RegExp(r'^/users/(\d+)$').firstMatch(path);
    if (profile != null && method == 'GET') {
      final target = int.parse(profile[1]!);
      user(target);
      if (target != owner && _blocked(owner, target)) {
        throw const _DemoError(
          403,
          'USER_BLOCKED',
          'Tài khoản không khả dụng khi chặn nhau.',
        );
      }
      return {
        ...user(target),
        'relationships': {
          'is_friend': target != owner,
          'is_following': false,
          'is_followed': false,
          'friend_request_status': 'NONE',
        },
      };
    }
    if (path == '/search' && method == 'GET') {
      final query = (uri.queryParameters['query'] ?? '').toLowerCase().trim();
      final users = [1, 2]
          .where((id) => id != owner && !_blocked(owner, id))
          .map(user)
          .where(
            (u) =>
                query.isEmpty ||
                '${u['full_name']} ${u['email']} ${u['student_lecturer_code']}'
                    .toLowerCase()
                    .contains(query),
          )
          .toList();
      return {
        ..._page(users.map((u) => {'type': 'USER', 'user': u}).toList(), uri),
        'total_hits': users.length,
      };
    }
    if (path == '/conversations' && method == 'GET') {
      final rows = _conversations.values
          .where(
            (c) =>
                (c['members'] as List).contains(owner) &&
                !_blocked(owner, _other(c, owner)),
          )
          .map((c) => _summary(c, owner))
          .toList();
      rows.sort((a, b) => '${b['updated_at']}'.compareTo('${a['updated_at']}'));
      return _page(rows, uri);
    }
    if (path == '/conversations/direct' && method == 'POST') {
      final target = body['target_user_id'];
      if (target is! int) {
        throw const _DemoError(400, '1002', 'Thiếu target_user_id.');
      }
      return _summary(_createConversation(owner, target), owner);
    }
    final conversation = RegExp(
      r'^/conversations/(\d+)/(messages|members)$',
    ).firstMatch(path);
    if (conversation != null && method == 'GET') {
      final c = _conversation(int.parse(conversation[1]!), owner);
      if (conversation[2] == 'members') {
        return (c['members'] as List).cast<int>().map(user).toList();
      }
      final rows = _messages(c, owner);
      if (rows.isNotEmpty) {
        final reads = c['reads'] as Map;
        reads['$owner'] = max(
          reads['$owner'] as int? ?? 0,
          rows.last['message_id'] as int,
        );
      }
      return {
        'conversation_id': c['conversation_id'],
        'conversation_type': 'DIRECT',
        ..._page(
          rows.reversed.map(_publicMessage).toList(),
          uri,
          key: 'messages',
        ),
      };
    }
    final deletion = RegExp(r'^/messages/(\d+)$').firstMatch(path);
    if (deletion != null && method == 'DELETE') {
      final id = int.parse(deletion[1]!);
      for (final c in _conversations.values) {
        for (final m in (c['messages'] as List).cast<Map<String, dynamic>>()) {
          if (m['message_id'] != id) continue;
          _conversation(c['conversation_id'] as int, owner);
          if (body['scope'] == 'EVERYONE') {
            if (m['sender_id'] != owner) {
              throw const _DemoError(
                403,
                '1009',
                'Chỉ thu hồi được tin của mình.',
              );
            }
            m['revoked'] = true;
            m['content'] = '';
            m['media_urls'] = <String>[];
          } else if (body['scope'] == 'ME') {
            (m['deleted_for'] as List).add(owner);
          } else {
            throw const _DemoError(
              400,
              '1002',
              'Scope phải là ME hoặc EVERYONE.',
            );
          }
          return {'message_id': id, 'scope': body['scope']};
        }
      }
      throw const _DemoError(404, '1004', 'Không tìm thấy tin nhắn.');
    }
    throw const _DemoError(404, '1004', 'Mock chat chưa hỗ trợ endpoint này.');
  }

  void _emit(
    String destination,
    Set<int> recipients,
    Map<String, dynamic> body,
  ) {
    for (final peer in _peers.toList()) {
      if (peer.owner == null || !recipients.contains(peer.owner)) continue;
      peer.deliver(destination, body);
    }
  }

  void _syncUsers(Set<int> recipients) =>
      _emit('/user/queue/messages', recipients, {'type': 'SYNC'});

  void _readEvent(Map<String, dynamic> c, int owner) => _emit(
    '/user/queue/messages',
    (c['members'] as List).cast<int>().toSet(),
    {
      'type': 'READ_RECEIPT',
      'conversation_id': c['conversation_id'],
      'reader_id': owner,
      'message_id': (c['reads'] as Map)['$owner'] ?? 0,
    },
  );

  Future<void> _command(
    _StompPeer peer,
    String command,
    Map<String, String> headers,
    String body,
  ) async {
    if (_closing) return;
    if (command == 'CONNECT' || command == 'STOMP') {
      final owner = _identity(
        headers['Authorization'] ?? headers['authorization'],
      );
      if (owner == null) {
        peer.error(
          const _DemoError(401, '1006', 'STOMP cần token tài khoản thử.'),
          fatal: true,
        );
        return;
      }
      peer.owner = owner;
      peer.frame('CONNECTED', {
        'version': '1.2',
        'heart-beat': '0,0',
        'session': 'demo-$owner',
      }, '');
      return;
    }
    final owner = peer.owner;
    if (owner == null) {
      peer.error(
        const _DemoError(401, '1006', 'Chưa xác thực STOMP.'),
        fatal: true,
      );
      return;
    }
    if (command == 'DISCONNECT') {
      if (headers['receipt'] != null) {
        peer.frame('RECEIPT', {'receipt-id': headers['receipt']!}, '');
      }
      await peer.socket.close(WebSocketStatus.normalClosure);
      return;
    }
    if (command == 'UNSUBSCRIBE') {
      peer.subscriptions.remove(headers['id']);
      return;
    }
    if (command == 'SUBSCRIBE') {
      final destination = headers['destination'];
      final id = headers['id'];
      if (destination == null || id == null) {
        throw const _DemoError(
          400,
          '1002',
          'Thiếu subscription id/destination.',
        );
      }
      if (destination != '/user/queue/messages') {
        final match = RegExp(
          r'^/topic/conv\.(\d+)\.typing$',
        ).firstMatch(destination);
        if (match == null) {
          throw const _DemoError(
            403,
            '1009',
            'Không có quyền đăng ký kênh này.',
          );
        }
        _conversation(int.parse(match[1]!), owner);
      }
      peer.subscriptions[id] = destination;
      return;
    }
    if (command != 'SEND') return;
    final data = jsonDecode(body);
    if (data is! Map<String, dynamic> || data['conversation_id'] is! int) {
      throw const _DemoError(400, '1002', 'Thiếu conversation_id.');
    }
    final id = data['conversation_id'] as int;
    final destination = headers['destination'];
    if (destination == '/app/chat.send') {
      final message = await _serial(() {
        final c = _conversation(id, owner);
        final content = data['content'];
        final media = data['media_urls'];
        final type = data['message_type'] ?? 'TEXT';
        if (content is! String ||
            content.length > 2000 ||
            media is! List ||
            media.length > 4 ||
            media.any(
              (url) =>
                  url is! String ||
                  !['http', 'https'].contains(Uri.tryParse(url)?.scheme),
            ) ||
            (content.trim().isEmpty && media.isEmpty) ||
            !['TEXT', 'IMAGE', 'VIDEO', 'GIF', 'DOCUMENT'].contains(type)) {
          throw const _DemoError(400, '1002', 'Tin nhắn không hợp lệ.');
        }
        final m = <String, dynamic>{
          'message_id': _nextMessageId++,
          'conversation_id': id,
          'sender_id': owner,
          'message_type': type,
          'content': content.trim(),
          'media_urls': List<String>.from(media),
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'revoked': false,
          'deleted_for': <int>[],
        };
        (c['messages'] as List).add(m);
        return _publicMessage(m);
      }, save: true);
      _emit('/user/queue/messages', {1, 2}, message);
    } else if (destination == '/app/chat.read') {
      final c = await _serial(() {
        final c = _conversation(id, owner);
        final messageId = data['message_id'];
        if (messageId is! int ||
            !(c['messages'] as List).any((m) => m['message_id'] == messageId)) {
          throw const _DemoError(400, '1002', 'message_id không hợp lệ.');
        }
        final reads = c['reads'] as Map;
        reads['$owner'] = max(reads['$owner'] as int? ?? 0, messageId);
        return c;
      }, save: true);
      _readEvent(c, owner);
    } else if (destination == '/app/chat.typing') {
      _conversation(id, owner);
      if (data['is_typing'] is! bool) {
        throw const _DemoError(400, '1002', 'is_typing phải là boolean.');
      }
      _emit(
        '/topic/conv.$id.typing',
        {1, 2},
        {
          'conversation_id': id,
          'user_id': owner,
          'is_typing': data['is_typing'],
        },
      );
    } else {
      throw const _DemoError(404, '1004', 'Destination không được hỗ trợ.');
    }
  }

  int _indexOf(List<int> bytes, List<int> marker, int start) {
    for (var i = start; i <= bytes.length - marker.length; i++) {
      var match = true;
      for (var j = 0; j < marker.length; j++) {
        if (bytes[i + j] != marker[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  Future<Map<String, dynamic>> _upload(HttpRequest request) async {
    final boundary = request.headers.contentType?.parameters['boundary'];
    if (boundary == null || boundary.length > 200) {
      throw const _DemoError(400, '1002', 'Thiếu multipart boundary.');
    }
    final bytes = await _bytes(request, limit: 4 * 1024 * 1024 + 64 * 1024);
    final marker = ascii.encode('--$boundary');
    var start = _indexOf(bytes, marker, 0);
    while (start >= 0) {
      final headersEnd = _indexOf(bytes, [
        13,
        10,
        13,
        10,
      ], start + marker.length);
      if (headersEnd < 0) break;
      final headers = latin1.decode(
        bytes.sublist(start + marker.length, headersEnd),
      );
      final end = _indexOf(
        bytes,
        ascii.encode('\r\n--$boundary'),
        headersEnd + 4,
      );
      if (end < 0) break;
      if (RegExp(r'name="file"(?:;|\s|$)').hasMatch(headers)) {
        final content = bytes.sublist(headersEnd + 4, end);
        if (content.isEmpty || content.length > 4 * 1024 * 1024) {
          throw const _DemoError(413, '1003', 'Ảnh vượt quá 4MB hoặc rỗng.');
        }
        final String extension;
        final String mime;
        if (content.length >= 8 &&
            content[0] == 137 &&
            content[1] == 80 &&
            content[2] == 78 &&
            content[3] == 71) {
          extension = 'png';
          mime = 'image/png';
        } else if (content.length >= 3 &&
            content[0] == 255 &&
            content[1] == 216 &&
            content[2] == 255) {
          extension = 'jpg';
          mime = 'image/jpeg';
        } else if (content.length >= 12 &&
            ascii.decode(content.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
            ascii.decode(content.sublist(8, 12), allowInvalid: true) ==
                'WEBP') {
          extension = 'webp';
          mime = 'image/webp';
        } else {
          throw const _DemoError(
            400,
            '1002',
            'Chỉ hỗ trợ ảnh PNG, JPEG hoặc WebP.',
          );
        }
        final random = Random.secure();
        final key =
            '${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}.$extension';
        final directory = Directory('${dataDirectory.path}/media');
        await directory.create(recursive: true);
        await File('${directory.path}/$key').writeAsBytes(content, flush: true);
        return {
          'object_key': key,
          'url': '$baseUrl/media/$key',
          'file_size': content.length,
          'content_type': mime,
          'media_type': 'IMAGE',
        };
      }
      start = end + 2;
    }
    throw const _DemoError(400, '1002', 'Thiếu trường file.');
  }

  Future<void> _serveMedia(HttpRequest request) async {
    final key = request.uri.path.split('/').last;
    if (!RegExp(r'^[a-f0-9]{32}\.(jpg|png|webp)$').hasMatch(key)) {
      throw const _DemoError(404, '1004', 'Không tìm thấy ảnh.');
    }
    final file = File('${dataDirectory.path}/media/$key');
    if (!await file.exists()) {
      throw const _DemoError(404, '1004', 'Không tìm thấy ảnh.');
    }
    request.response.headers.contentType = ContentType(
      'image',
      key.endsWith('.jpg') ? 'jpeg' : key.split('.').last,
    );
    request.response.contentLength = await file.length();
    await file.openRead().pipe(request.response);
  }

  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    await _http.close(force: true);
    for (final peer in _peers.toList()) {
      await peer.socket.close(WebSocketStatus.goingAway);
    }
    await _pending;
  }
}

class _DemoError implements Exception {
  final int status;
  final String code;
  final String message;
  const _DemoError(this.status, this.code, this.message);
}

class _StompPeer {
  final ChatDemoServer server;
  final WebSocket socket;
  final Map<String, String> subscriptions = {};
  int? owner;
  String _buffer = '';
  Future<void> _pendingFrames = Future<void>.value();
  _StompPeer(this.server, this.socket);

  void listen() {
    socket.listen(
      (dynamic data) {
        _buffer += data is String ? data : utf8.decode(data as List<int>);
        while (_buffer.startsWith('\n') || _buffer.startsWith('\r')) {
          _buffer = _buffer.substring(1);
        }
        while (_buffer.contains('\u0000')) {
          final end = _buffer.indexOf('\u0000');
          final frame = _buffer.substring(0, end).replaceAll('\r\n', '\n');
          _buffer = _buffer.substring(end + 1);
          if (frame.trim().isEmpty) continue;
          final before = _pendingFrames;
          _pendingFrames = () async {
            await before;
            try {
              final split = frame.indexOf('\n\n');
              final head = (split < 0 ? frame : frame.substring(0, split))
                  .split('\n');
              final headers = <String, String>{};
              for (final line in head.skip(1)) {
                final colon = line.indexOf(':');
                if (colon > 0) {
                  headers[line.substring(0, colon)] = line
                      .substring(colon + 1)
                      .replaceAll(r'\n', '\n')
                      .replaceAll(r'\r', '\r')
                      .replaceAll(r'\c', ':')
                      .replaceAll(r'\\', '\\');
                }
              }
              await server._command(
                this,
                head.first.trim(),
                headers,
                split < 0 ? '' : frame.substring(split + 2),
              );
            } on _DemoError catch (e) {
              error(e, conversationId: _conversationId(frame));
            } on FormatException {
              error(
                const _DemoError(
                  400,
                  '1002',
                  'Frame chat không đúng định dạng.',
                ),
              );
            } catch (_) {
              error(
                const _DemoError(500, '1001', 'Không thể xử lý frame chat.'),
              );
            }
          }();
        }
      },
      onDone: () => server._peers.remove(this),
      onError: (Object _) => server._peers.remove(this),
    );
  }

  int _conversationId(String frame) {
    final split = frame.indexOf('\n\n');
    if (split < 0) return 0;
    try {
      final body = jsonDecode(frame.substring(split + 2));
      return body is Map && body['conversation_id'] is int
          ? body['conversation_id'] as int
          : 0;
    } on FormatException {
      return 0;
    }
  }

  void frame(String command, Map<String, String> headers, String body) {
    if (socket.readyState != WebSocket.open) return;
    final lines = [
      command,
      for (final entry in headers.entries) '${entry.key}:${entry.value}',
      if (body.isNotEmpty) 'content-length:${utf8.encode(body).length}',
      '',
      body,
    ];
    try {
      socket.add('${lines.join('\n')}\u0000');
    } on StateError {
      /* Socket vừa đóng. */
    }
  }

  void deliver(String destination, Map<String, dynamic> body) {
    for (final entry in subscriptions.entries) {
      if (entry.value != destination) continue;
      frame('MESSAGE', {
        'subscription': entry.key,
        'message-id': '${server._frameId++}',
        'destination': destination,
        'content-type': 'application/json',
      }, jsonEncode(body));
    }
  }

  void error(_DemoError error, {int conversationId = 0, bool fatal = false}) {
    final body = {
      'code': error.code,
      'message': error.message,
      'data': {'conversation_id': conversationId},
    };
    if (fatal) {
      frame('ERROR', {'message': error.message}, jsonEncode(body));
      unawaited(socket.close(WebSocketStatus.policyViolation));
    } else {
      deliver('/user/queue/messages', body);
    }
  }
}

Future<void> main(List<String> arguments) async {
  var port = 8787;
  var path = '.local/chat-demo';
  for (var i = 0; i < arguments.length; i++) {
    final arg = arguments[i];
    if (arg.startsWith('--port=')) {
      port = int.parse(arg.substring(7));
    } else if (arg == '--port' && i + 1 < arguments.length) {
      port = int.parse(arguments[++i]);
    } else if (arg.startsWith('--data-dir=')) {
      path = arg.substring(11);
    } else if (arg == '--data-dir' && i + 1 < arguments.length) {
      path = arguments[++i];
    } else {
      stderr.writeln(
        'Usage: dart run tool/chat_demo_server.dart [--port 8787] [--data-dir .local/chat-demo]',
      );
      exitCode = 64;
      return;
    }
  }
  final server = await ChatDemoServer.start(
    dataDirectory: Directory(path),
    port: port,
  );
  stdout.writeln('QuizHub chat demo: ${server.baseUrl}');
  stdout.writeln(
    'An: chat-demo-1 | Lan: chat-demo-2. Dữ liệu: ${server.dataDirectory.absolute.path}',
  );
  for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
    signal.watch().listen((_) async {
      await server.close();
      exit(0);
    });
  }
}
