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
import 'package:shared_preferences/shared_preferences.dart';

/// Kho thông tin đăng nhập giả trong RAM (không đụng Keystore thật).
class MemoryCredentials extends CredentialStorage {
  SavedAccount? value;

  MemoryCredentials([this.value]);

  @override
  Future<SavedAccount?> read() async => value;
  @override
  Future<void> save(SavedAccount account) async => value = account;
  @override
  Future<void> clear() async => value = null;
}

class _Tokens extends TokenStorage {
  @override
  String? get accessToken => 'a';
  @override
  String? get refreshToken => 'r';
  @override
  bool get hasTokens => true;
  @override
  Future<void> load() async {}
  @override
  Future<void> clear() async {}
}

class _Adapter implements HttpClientAdapter {
  final int status;
  _Adapter(this.status);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({'code': status == 200 ? '0000' : '9990', 'message': 'x'}),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  group('SavedAccount', () {
    test('encode/decode round trip', () {
      const a = SavedAccount(
        email: 'an@sis.hust.edu.vn',
        password: 'Abc@12345',
        fullName: 'Nguyễn Văn An',
        avatarUrl: 'https://x/y.png',
      );
      expect(SavedAccount.decode(a.encode()), a);
    });

    test('decode tolerates garbage and missing fields', () {
      expect(SavedAccount.decode(null), isNull);
      expect(SavedAccount.decode(''), isNull);
      expect(SavedAccount.decode('not json'), isNull);
      expect(SavedAccount.decode('{"email":"a@b.c"}'), isNull);
      expect(SavedAccount.decode('{"password":"x"}'), isNull);
    });

    test('displayName falls back to email', () {
      const noName = SavedAccount(email: 'a@b.c', password: 'x');
      const named = SavedAccount(
        email: 'a@b.c',
        password: 'x',
        fullName: ' Lan ',
      );
      expect(noName.displayName, 'a@b.c');
      expect(named.displayName, 'Lan');
    });
  });

  group('AuthRepository + saved account', () {
    late LocalStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorage(await SharedPreferences.getInstance());
    });

    AuthRepository repo(MemoryCredentials creds, int status) => AuthRepository(
      ApiClient(
        tokens: _Tokens(),
        events: SessionEvents(),
        baseUrl: 'https://example.com/api/v1',
        adapter: _Adapter(status),
      ),
      _Tokens(),
      storage,
      DeviceService(storage),
      creds,
    );

    test('remember / read / forget', () async {
      final creds = MemoryCredentials();
      final r = repo(creds, 200);

      expect(await r.savedAccount(), isNull);
      await r.rememberAccount(
        const SavedAccount(email: 'an@x.vn', password: 'p1'),
      );
      expect((await r.savedAccount())?.email, 'an@x.vn');

      await r.forgetAccount();
      expect(await r.savedAccount(), isNull);
    });

    test('changing password also updates the saved password', () async {
      final creds = MemoryCredentials(
        const SavedAccount(email: 'an@x.vn', password: 'old', fullName: 'An'),
      );

      await repo(
        creds,
        200,
      ).changePassword(oldPassword: 'old', newPassword: 'Newpass@1');

      expect(creds.value?.password, 'Newpass@1');
      expect(creds.value?.fullName, 'An'); // giữ nguyên các trường khác
    });

    test('failed password change keeps the saved password', () async {
      final creds = MemoryCredentials(
        const SavedAccount(email: 'an@x.vn', password: 'old'),
      );

      await expectLater(
        repo(creds, 400).changePassword(oldPassword: 'x', newPassword: 'y'),
        throwsA(anything),
      );
      expect(creds.value?.password, 'old');
    });

    test('updateProfile only touches the matching account', () async {
      final creds = MemoryCredentials(
        const SavedAccount(email: 'an@x.vn', password: 'p'),
      );

      await creds.updateProfile(email: 'khac@x.vn', fullName: 'Người khác');
      expect(creds.value?.fullName, isNull);

      await creds.updateProfile(email: 'AN@x.vn', fullName: 'An');
      expect(creds.value?.fullName, 'An');
    });
  });
}
