import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/session_events.dart';
import 'package:quizhub/core/services/device_service.dart';
import 'package:quizhub/core/storage/credential_storage.dart';
import 'package:quizhub/core/storage/local_storage.dart';
import 'package:quizhub/core/storage/token_storage.dart';
import 'package:quizhub/data/models/saved_account.dart';
import 'package:quizhub/data/repositories/auth_repository.dart';
import 'package:quizhub/features/auth/cubit/auth_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryTokens extends TokenStorage {
  String? _access;
  String? _refresh;

  _MemoryTokens({String? access, String? refresh})
    : _access = access,
      _refresh = refresh;

  @override
  String? get accessToken => _access;
  @override
  String? get refreshToken => _refresh;
  @override
  bool get hasTokens => (_refresh ?? '').isNotEmpty;
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

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}

class _Credentials extends CredentialStorage {
  @override
  Future<SavedAccount?> read() async => null;
  @override
  Future<void> save(SavedAccount account) async {}
  @override
  Future<void> clear() async {}
}

class _AuthRepository implements AuthRepository {
  @override
  bool hasSession;
  int clearCalls = 0;

  _AuthRepository({required this.hasSession});

  @override
  Future<void> logout() async {
    await clearLocalSession();
  }
  @override
  Future<void> clearLocalSession() async {
    clearCalls++;
    hasSession = false;
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({'code': '9999', 'message': 'server unavailable', 'data': null}),
    503,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  group('Vòng đời phiên AuthCubit', () {
    late SessionEvents events;

    setUp(() => events = SessionEvents());
    tearDown(() => events.dispose());

    test('Có token thì bootstrap vào trạng thái đã đăng nhập', () async {
      final cubit = AuthCubit(_AuthRepository(hasSession: true), events);
      addTearDown(cubit.close);

      cubit.bootstrap();

      expect(cubit.state.status, AuthStatus.authenticated);
      expect(cubit.state.sessionExpired, false);
    });

    test('Không có token thì bootstrap yêu cầu đăng nhập', () async {
      final cubit = AuthCubit(_AuthRepository(hasSession: false), events);
      addTearDown(cubit.close);

      cubit.bootstrap();

      expect(cubit.state.status, AuthStatus.unauthenticated);
      expect(cubit.state.sessionExpired, false);
    });

    test('Hết phiên xoá dữ liệu một lần; login lại bỏ cờ hết hạn', () async {
      final repo = _AuthRepository(hasSession: true);
      final cubit = AuthCubit(repo, events);
      addTearDown(cubit.close);
      cubit.bootstrap();

      final expired = cubit.stream.firstWhere((s) => s.sessionExpired);
      events.notifySessionExpired();
      await expired;

      expect(cubit.state.status, AuthStatus.unauthenticated);
      expect(repo.clearCalls, 1);

      events.notifySessionExpired();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.sessionExpired, true);
      expect(repo.clearCalls, 1);

      cubit.loggedIn();
      expect(cubit.state.status, AuthStatus.authenticated);
      expect(cubit.state.sessionExpired, false);
    });

    test('Logout vẫn xoá token và cache khi server trả 503', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorage(prefs);
      await storage.setCachedUser({'user_id': 1});
      await storage.setHomeFeedCache({'items': []});

      final tokens = _MemoryTokens(access: 'access', refresh: 'refresh');
      final repo = AuthRepository(
        ApiClient(
          tokens: tokens,
          events: events,
          baseUrl: 'https://example.com/api/v1',
          adapter: _FailingAdapter(),
        ),
        tokens,
        storage,
        DeviceService(storage),
        _Credentials(),
      );
      final cubit = AuthCubit(repo, events);
      addTearDown(cubit.close);
      cubit.bootstrap();

      await cubit.logout();

      expect(cubit.state.status, AuthStatus.unauthenticated);
      expect(tokens.hasTokens, false);
      expect(storage.cachedUser, isNull);
      expect(storage.homeFeedCache, isNull);
    });
  });
}
