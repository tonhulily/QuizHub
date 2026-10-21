import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/api_exception.dart';
import 'package:quizhub/core/network/session_events.dart';
import 'package:quizhub/core/storage/token_storage.dart';

class _Tokens extends TokenStorage {
  String? _access = 'dummy-access';
  String? _refresh = 'dummy-refresh';

  @override
  String? get accessToken => _access;

  @override
  String? get refreshToken => _refresh;

  @override
  bool get hasTokens => _refresh != null;

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }

  @override
  Future<void> load() async {}

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _access = accessToken;
    _refresh = refreshToken;
  }
}

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> calls = [];
  final Future<ResponseBody> Function(RequestOptions options) respond;

  _RecordingAdapter(this.respond);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Map<String, Object?> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  test(
    'protected redirect must block or strip credentials off origin',
    () async {
      var redirectResponses = 0;
      final adapter = _RecordingAdapter((options) async {
        if (options.uri.host == 'api.test') {
          redirectResponses++;
          return ResponseBody.fromString(
            '',
            308,
            headers: {
              'location': ['https://other.test/capture'],
            },
          );
        }
        return _json(200, {
          'code': '0000',
          'message': 'ok',
          'data': {'accepted': true},
        });
      });
      final events = SessionEvents();
      final api = ApiClient(
        tokens: _Tokens(),
        events: events,
        baseUrl: 'https://api.test/api/v1',
        adapter: adapter,
      );

      var blocked = false;
      try {
        await api.post<Map<String, dynamic>>(
          '/posts',
          body: {'marker': 'dummy-body'},
          parser: (data) => data as Map<String, dynamic>,
        );
      } on ApiException {
        blocked = true;
      }

      final externalRequests = adapter.calls
          .where((request) => request.uri.host == 'other.test')
          .toList();
      expect(redirectResponses, 1);
      expect(externalRequests.length, lessThanOrEqualTo(1));
      if (externalRequests.isEmpty) {
        expect(blocked, isTrue);
      } else {
        expect(blocked, isFalse);
        final observed = {
          'authorization': externalRequests.single.headers['Authorization'],
          'body': externalRequests.single.data,
        };
        expect(observed, {'authorization': null, 'body': null});
      }
      events.dispose();
    },
  );

  test(
    'parallel 401 callers must both retain network error on refresh timeout',
    () async {
      final bothUnauthorized = Completer<void>();
      final refreshStarted = Completer<void>();
      final releaseRefresh = Completer<void>();
      var unauthorizedCount = 0;
      final tokens = _Tokens();
      final events = SessionEvents();
      var sessionExpiredCount = 0;
      final subscription = events.onSessionExpired.listen((_) {
        sessionExpiredCount++;
      });
      final adapter = _RecordingAdapter((options) async {
        if (options.path == '/auth/refresh') {
          if (!refreshStarted.isCompleted) refreshStarted.complete();
          await releaseRefresh.future;
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
          );
        }

        unauthorizedCount++;
        if (unauthorizedCount == 2) bothUnauthorized.complete();
        return _json(401, {'code': '9998', 'message': 'expired', 'data': null});
      });
      final api = ApiClient(tokens: tokens, events: events, adapter: adapter);

      Future<ApiException> capture(Future<void> request) async {
        try {
          await request;
        } on ApiException catch (error) {
          return error;
        }
        fail('Expected the protected request to fail.');
      }

      final first = capture(api.get<void>('/first', parser: (_) {}));
      await refreshStarted.future;
      final second = capture(api.get<void>('/second', parser: (_) {}));
      await bothUnauthorized.future;
      for (var turn = 0; turn < 4; turn++) {
        await Future<void>.delayed(Duration.zero);
      }
      releaseRefresh.complete();
      final errors = await Future.wait([first, second]);
      await Future<void>.delayed(Duration.zero);

      final observed = {
        'errorTypes': errors.map((error) => error.type).toList(),
        'tokensRetained': tokens.hasTokens,
        'sessionExpiredCount': sessionExpiredCount,
        'refreshCalls': adapter.calls
            .where((request) => request.path == '/auth/refresh')
            .length,
      };
      await subscription.cancel();
      events.dispose();
      expect(observed, {
        'errorTypes': [ApiErrorType.noConnection, ApiErrorType.noConnection],
        'tokensRetained': true,
        'sessionExpiredCount': 0,
        'refreshCalls': 1,
      });
    },
  );
}
