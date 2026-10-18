import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lưu JWT (access + refresh) trong Keychain / Keystore.
///
/// Giữ bản cache trong RAM để interceptor đọc đồng bộ nhanh.
class TokenStorage {
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  final FlutterSecureStorage _storage;

  String? _access;
  String? _refresh;

  TokenStorage([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  String? get accessToken => _access;
  String? get refreshToken => _refresh;
  bool get hasTokens => (_refresh ?? '').isNotEmpty;

  /// Nạp token từ bộ nhớ an toàn vào RAM (gọi 1 lần khi khởi động app).
  Future<void> load() async {
    try {
      _access = await _storage.read(key: _kAccess);
      _refresh = await _storage.read(key: _kRefresh);
    } catch (_) {
      // Keystore bị hỏng (vd restore backup) -> coi như chưa đăng nhập
      await clear();
    }
  }

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _access = accessToken;
    _refresh = refreshToken;
    await _storage.write(key: _kAccess, value: accessToken);
    await _storage.write(key: _kRefresh, value: refreshToken);
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    try {
      await _storage.delete(key: _kAccess);
      await _storage.delete(key: _kRefresh);
    } catch (_) {}
  }
}
