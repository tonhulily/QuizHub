import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/api_exception.dart';
import 'package:quizhub/core/network/session_events.dart';
import 'package:quizhub/data/repositories/chat_repository.dart';
import 'package:quizhub/dev/shared_chat_demo.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/chat_demo_server.dart';

class _RealHttpOverrides extends HttpOverrides {}

class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'code': '0000', 'data': {}}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'cache tách theo tài khoản/server và clear không đụng dữ liệu preview cũ',
    () async {
      const oldUser = '{"user_id":99,"full_name":"Tài khoản cũ"}';
      SharedPreferences.setMockInitialValues({
        'cached_user': oldUser,
        'preview_chat_v1_1': 'chat preview cũ',
      });
      final original = await SharedPreferences.getInstance();
      final first = SharedChatDemoConfig(
        apiBaseUrl: 'http://localhost:8787/api/v1/',
        userId: 1,
      );
      final second = SharedChatDemoConfig(
        apiBaseUrl: 'http://localhost:8787/api/v1',
        userId: 2,
      );
      final otherServer = SharedChatDemoConfig(
        apiBaseUrl: 'http://localhost:8989/api/v1',
        userId: 1,
      );
      final an = SharedChatDemoPreferences(original, prefix: first.cachePrefix);
      final lan = SharedChatDemoPreferences(
        original,
        prefix: second.cachePrefix,
      );
      final other = SharedChatDemoPreferences(
        original,
        prefix: otherServer.cachePrefix,
      );
      expect(
        first.cachePrefix,
        SharedChatDemoConfig(
          apiBaseUrl: 'http://localhost:8787/api/v1',
          userId: 1,
        ).cachePrefix,
      );
      expect({
        first.cachePrefix,
        second.cachePrefix,
        otherServer.cachePrefix,
      }, hasLength(3));
      expect(an.get('cached_user'), isNull);
      expect(lan.get('preview_chat_v1_1'), isNull);

      await an.setString('cached_user', '{"user_id":1}');
      await an.setString('preview_chat_v1_1', 'chat của An');
      await an.setStringList('muted', ['1']);
      await an.setBool('remember', true);
      await an.setInt('last_read', 7);
      await an.setDouble('scale', 1.25);
      await lan.setString('cached_user', '{"user_id":2}');
      await lan.setString('preview_chat_v1_1', 'chat của Lan');
      await other.setString('cached_user', '{"user_id":1,"server":"khác"}');
      expect(an.getString('cached_user'), '{"user_id":1}');
      expect(an.getStringList('muted'), ['1']);
      expect(an.getBool('remember'), isTrue);
      expect(an.getInt('last_read'), 7);
      expect(an.getDouble('scale'), 1.25);
      expect(an.getKeys(), {
        'cached_user',
        'preview_chat_v1_1',
        'muted',
        'remember',
        'last_read',
        'scale',
      });
      expect(await an.remove('last_read'), isTrue);
      expect(an.containsKey('last_read'), isFalse);
      expect(await an.clear(), isTrue);
      expect(an.getKeys(), isEmpty);
      expect(lan.getString('cached_user'), '{"user_id":2}');
      expect(lan.getString('preview_chat_v1_1'), 'chat của Lan');
      expect(other.getString('cached_user'), '{"user_id":1,"server":"khác"}');
      expect(original.getString('cached_user'), oldUser);
      expect(original.getString('preview_chat_v1_1'), 'chat preview cũ');
    },
  );

  test('config chuẩn hoá URL và không nhận user/server không hợp lệ', () {
    final config = SharedChatDemoConfig(
      apiBaseUrl: 'https://chat.example.test/api/v1///',
      userId: 2,
    );
    expect(config.apiBaseUrl, 'https://chat.example.test/api/v1');
    expect(config.webSocketUrl, 'wss://chat.example.test/api/v1/ws/websocket');
    expect(config.displayName, 'Trần Thị Lan');
    for (final id in [-1, 0, 3]) {
      expect(() => SharedChatDemoConfig(userId: id), throwsFormatException);
    }
    for (final url in [
      'file:///tmp/chat',
      'ftp://host/api',
      'http://',
      'https://user:password@host/api',
      'https://host/api?q=x',
      'https://host/api#part',
    ]) {
      expect(
        () => SharedChatDemoConfig(apiBaseUrl: url),
        throwsFormatException,
      );
    }
  });

  test('demo token chỉ lưu danh tính của phiên test đang mở', () async {
    final tokens = SharedChatDemoTokens(2);
    expect(tokens.accessToken, 'chat-demo-2');
    expect(tokens.hasTokens, isTrue);
    await expectLater(
      tokens.save(
        accessToken: 'chat-demo-1',
        refreshToken: 'chat-demo-refresh-1',
      ),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      tokens.save(
        accessToken: 'production-session-placeholder',
        refreshToken: 'production-refresh-placeholder',
      ),
      throwsA(isA<ApiException>()),
    );
    expect(tokens.accessToken, 'chat-demo-2');
    await tokens.clear();
    expect(tokens.accessToken, isNull);
    expect(tokens.hasTokens, isFalse);
    await tokens.save(
      accessToken: 'chat-demo-2',
      refreshToken: 'chat-demo-refresh-2',
    );
    expect(tokens.hasTokens, isTrue);
  });

  test('adapter bỏ token phiên khác và từ chối gọi URL tuyệt đối', () async {
    final remote = _RecordingAdapter();
    final local = _RecordingAdapter();
    final config = SharedChatDemoConfig(userId: 2);
    final adapter = SharedChatDemoAdapter(
      config: config,
      remoteAdapter: remote,
      localAdapter: local,
    );
    addTearDown(() => adapter.close(force: true));
    for (final token in [
      'Bearer production-session-placeholder',
      'Bearer chat-demo-1',
    ]) {
      await adapter.fetch(
        RequestOptions(
          path: '/users/me',
          baseUrl: 'https://unused.invalid/api/v1',
          headers: {'authorization': token},
        ),
        null,
        null,
      );
      expect(
        remote.requests.last.headers.keys.any(
          (k) => k.toLowerCase() == 'authorization',
        ),
        isFalse,
      );
      expect(remote.requests.last.baseUrl, config.apiBaseUrl);
      expect(remote.requests.last.followRedirects, isFalse);
    }
    await adapter.fetch(
      RequestOptions(
        path: '/users/me',
        headers: {'Authorization': 'Bearer chat-demo-2'},
      ),
      null,
      null,
    );
    expect(remote.requests.last.headers['Authorization'], 'Bearer chat-demo-2');
    expect(local.requests, isEmpty);
    expect(
      () => adapter.fetch(
        RequestOptions(path: 'https://unused.invalid/users/me'),
        null,
        null,
      ),
      throwsA(isA<DioException>()),
    );
  });

  test(
    'adapter dùng chung server cho An/Lan; feed vẫn là dữ liệu local',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'quizhub-adapter-chat-',
      );
      final server = await ChatDemoServer.start(dataDirectory: directory);
      var serverClosed = false;
      final events = <SessionEvents>[];
      final adapters = <SharedChatDemoAdapter>[];
      addTearDown(() async {
        for (final adapter in adapters) {
          adapter.close(force: true);
        }
        for (final session in events) {
          session.dispose();
        }
        if (!serverClosed) await server.close();
        await directory.delete(recursive: true);
      });
      ApiClient client(int id) {
        final config = SharedChatDemoConfig(
          apiBaseUrl: server.baseUrl,
          userId: id,
        );
        final adapter = SharedChatDemoAdapter(
          config: config,
          remoteAdapter: IOHttpClientAdapter(
            createHttpClient: () => HttpOverrides.runWithHttpOverrides(
              () => HttpClient(),
              _RealHttpOverrides(),
            ),
          ),
        );
        final session = SessionEvents();
        adapters.add(adapter);
        events.add(session);
        return ApiClient(
          tokens: SharedChatDemoTokens(id),
          events: session,
          // Adapter phải đưa API chat tới server demo kể cả khi URL gốc khác.
          baseUrl: 'https://unused.invalid/api/v1',
          adapter: adapter,
        );
      }

      final an = client(1);
      final lan = client(2);
      final user1 = await an.get(
        '/users/me',
        parser: (data) => Map<String, dynamic>.from(data as Map),
      );
      final user2 = await lan.get(
        '/users/me',
        parser: (data) => Map<String, dynamic>.from(data as Map),
      );
      expect(user1['user_id'], 1);
      expect(user1['full_name'], 'Nguyễn Văn An');
      expect(user2['user_id'], 2);
      expect(user2['full_name'], 'Trần Thị Lan');
      final first = await ChatRepository(an).direct(2, myId: 1);
      final second = await ChatRepository(lan).direct(1, myId: 2);
      expect(first.conversationId, second.conversationId);
      expect(first.peer(1)?.userId, 2);
      expect(second.peer(2)?.userId, 1);
      expect(
        (await ChatRepository(
          lan,
        ).conversations()).items.map((c) => c.conversationId),
        contains(first.conversationId),
      );
      await server.close();
      serverClosed = true;
      final feed = await lan.get(
        '/activity-feeds',
        parser: (data) => Map<String, dynamic>.from(data as Map),
      );
      expect(feed['items'], isA<List>());
      expect((feed['items'] as List), isNotEmpty);
    },
  );
}
