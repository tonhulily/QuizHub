import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/api_exception.dart';
import 'package:quizhub/core/network/session_events.dart';
import 'package:quizhub/core/storage/token_storage.dart';

/// Adapter giả: trả response theo handler, ghi lại request đã gọi.
class FakeAdapter implements HttpClientAdapter {
  final List<RequestOptions> calls = [];
  final ResponseBody Function(RequestOptions o, int callIndex) handler;

  FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    return handler(options, calls.length);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(int status, Map<String, dynamic> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class MemoryTokens extends TokenStorage {
  String? _a;
  String? _r;

  MemoryTokens({String? access, String? refresh}) : _a = access, _r = refresh;

  @override
  String? get accessToken => _a;
  @override
  String? get refreshToken => _r;
  @override
  bool get hasTokens => (_r ?? '').isNotEmpty;
  @override
  Future<void> load() async {}
  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _a = accessToken;
    _r = refreshToken;
  }

  @override
  Future<void> clear() async {
    _a = null;
    _r = null;
  }
}

void main() {
  test('unwraps data on success code 0000', () async {
    final adapter = FakeAdapter(
      (o, _) => json(200, {
        'code': '0000',
        'message': 'ok',
        'data': {'x': 1},
      }),
    );
    final api = ApiClient(
      tokens: MemoryTokens(access: 'a', refresh: 'r'),
      events: SessionEvents(),
      adapter: adapter,
    );

    final res = await api.get<int>('/ping', parser: (d) => d['x'] as int);
    expect(res, 1);
    expect(adapter.calls.single.headers['Authorization'], 'Bearer a');
  });

  test('maps business error (HTTP 400 + code 9990)', () async {
    final adapter = FakeAdapter(
      (o, _) =>
          json(400, {'code': '9990', 'message': 'Sai mật khẩu', 'data': null}),
    );
    final api = ApiClient(
      tokens: MemoryTokens(),
      events: SessionEvents(),
      adapter: adapter,
    );

    await expectLater(
      api.post<void>('/auth/login', body: {}, parser: (_) {}),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', '9990')
            .having((e) => e.type, 'type', ApiErrorType.business)
            .having((e) => e.message, 'message', 'Sai mật khẩu'),
      ),
    );
    // login là public -> không gắn token
    expect(adapter.calls.single.headers.containsKey('Authorization'), false);
  });

  test('follows HTTP 308 on POST, keeping method and body', () async {
    final adapter = FakeAdapter((o, i) {
      if (i == 1) {
        return ResponseBody.fromString(
          '',
          308,
          headers: {
            'location': ['https://example.com/api/v1/auth/login'],
          },
        );
      }
      return json(200, {
        'code': '0000',
        'message': 'ok',
        'data': {'x': 7},
      });
    });
    final api = ApiClient(
      tokens: MemoryTokens(),
      events: SessionEvents(),
      baseUrl: 'https://example.com/api/v1',
      adapter: adapter,
    );

    final res = await api.post<int>(
      '/auth/login',
      body: {'email': 'a'},
      parser: (d) => d['x'] as int,
    );
    expect(res, 7);
    expect(adapter.calls.length, 2);
    expect(adapter.calls.last.method, 'POST');
    expect(adapter.calls.last.data, {'email': 'a'});
  });

  test('gives up on endless 308 redirect loop', () async {
    final adapter = FakeAdapter(
      (o, _) => ResponseBody.fromString(
        '',
        308,
        headers: {
          'location': ['https://example.com/api/v1/auth/login'],
        },
      ),
    );
    final api = ApiClient(
      tokens: MemoryTokens(),
      events: SessionEvents(),
      baseUrl: 'https://example.com/api/v1',
      adapter: adapter,
    );

    await expectLater(
      api.post<void>('/auth/login', body: {}, parser: (_) {}),
      throwsA(
        isA<ApiException>()
            .having((e) => e.type, 'type', ApiErrorType.server)
            .having((e) => e.message, 'message', contains('chuyển hướng')),
      ),
    );
    expect(adapter.calls.length, 3); // 1 gốc + tối đa 2 lần redirect
  });

  test('maps validation error with field errors', () async {
    final adapter = FakeAdapter(
      (o, _) => json(400, {
        'code': '1002',
        'message': 'thiếu',
        'data': [
          {'field': 'email', 'message': 'MISSING_REQUIRED_PARAMETER'},
        ],
      }),
    );
    final api = ApiClient(
      tokens: MemoryTokens(access: 'a', refresh: 'r'),
      events: SessionEvents(),
      adapter: adapter,
    );

    await expectLater(
      api.get<void>('/x', parser: (_) {}),
      throwsA(
        isA<ApiException>()
            .having((e) => e.type, 'type', ApiErrorType.validation)
            .having((e) => e.fieldErrors['email'], 'field', isNotNull),
      ),
    );
  });

  test('refreshes token once on 401 and retries the request', () async {
    final tokens = MemoryTokens(access: 'old', refresh: 'rt');
    final adapter = FakeAdapter((o, i) {
      if (o.path == '/auth/refresh') {
        return json(200, {
          'code': '0000',
          'message': 'ok',
          'data': {'access_token': 'new', 'refresh_token': 'rt2'},
        });
      }
      if (o.headers['Authorization'] == 'Bearer new') {
        return json(200, {'code': '0000', 'message': 'ok', 'data': 'done'});
      }
      return json(401, {'code': '9998', 'message': 'expired', 'data': null});
    });
    final api = ApiClient(
      tokens: tokens,
      events: SessionEvents(),
      adapter: adapter,
    );

    // 3 request song song cùng 401 -> chỉ refresh đúng 1 lần
    final results = await Future.wait([
      api.get<String>('/a', parser: (d) => d as String),
      api.get<String>('/b', parser: (d) => d as String),
      api.get<String>('/c', parser: (d) => d as String),
    ]);

    expect(results, ['done', 'done', 'done']);
    expect(adapter.calls.where((c) => c.path == '/auth/refresh').length, 1);
    expect(tokens.accessToken, 'new');
    expect(tokens.refreshToken, 'rt2');
  });

  test('emits session expired and clears tokens when refresh fails', () async {
    final tokens = MemoryTokens(access: 'old', refresh: 'bad');
    final events = SessionEvents();
    final expired = <void>[];
    events.onSessionExpired.listen(expired.add);

    final adapter = FakeAdapter((o, i) {
      if (o.path == '/auth/refresh') {
        return json(500, {'code': '9999', 'message': 'bad jwt', 'data': null});
      }
      return json(401, {'code': '9998', 'message': 'expired', 'data': null});
    });
    final api = ApiClient(tokens: tokens, events: events, adapter: adapter);

    await expectLater(
      api.get<void>('/me', parser: (_) {}),
      throwsA(
        isA<ApiException>().having(
          (e) => e.type,
          'type',
          ApiErrorType.unauthorized,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(expired.length, 1);
    expect(tokens.hasTokens, false);
  });
}
