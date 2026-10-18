import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/services/device_service.dart';
import '../../core/storage/credential_storage.dart';
import '../../core/storage/local_storage.dart';
import '../../core/storage/token_storage.dart';
import '../../core/utils/json_utils.dart';
import '../models/auth_session.dart';
import '../models/saved_account.dart';

/// Đăng nhập / đăng xuất / đổi mật khẩu + quản lý token.
///
/// (Đăng ký / xác thực OTP / quên mật khẩu do giảng viên tạo tài khoản đầu kỳ
/// nên app không có.)
class AuthRepository {
  final ApiClient _api;
  final TokenStorage _tokens;
  final LocalStorage _storage;
  final DeviceService _device;
  final CredentialStorage _credentials;

  AuthRepository(
    this._api,
    this._tokens,
    this._storage,
    this._device,
    this._credentials,
  );

  bool get hasSession => _tokens.hasTokens;

  /// `POST /auth/login` -> lưu token an toàn và trả về [AuthSession].
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final device = await _device.getInfo();
    final session = await _api.post<AuthSession>(
      ApiEndpoints.login,
      body: {
        'email': email.trim(),
        'password': password,
        'device_id': device.deviceId,
        'platform': device.platform,
        'device_name': device.deviceName,
        'os_version': device.osVersion,
        'app_version': device.appVersion,
      },
      parser: (d) => AuthSession.fromJson(J.asMap(d) ?? const {}),
    );
    await _tokens.save(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
    return session;
  }

  /// `POST /auth/logout` - luôn xoá dữ liệu cục bộ kể cả khi server lỗi/mất mạng.
  Future<void> logout() async {
    try {
      if (_tokens.hasTokens) {
        await _api.postVoid(ApiEndpoints.logout);
      }
    } catch (_) {
      // Bỏ qua: phiên cục bộ vẫn phải được xoá
    } finally {
      await clearLocalSession();
    }
  }

  /// Xoá token + dữ liệu cache của user (dùng khi logout / hết phiên).
  Future<void> clearLocalSession() async {
    await _tokens.clear();
    await _storage.clearUserData();
  }

  /// `POST /auth/change-password`
  ///
  /// Nếu máy đang lưu mật khẩu của tài khoản này thì cập nhật luôn, tránh lần
  /// sau bấm "đăng nhập nhanh" bằng mật khẩu cũ.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _api.postVoid(
      ApiEndpoints.changePassword,
      body: {'old_password': oldPassword, 'new_password': newPassword},
    );
    final saved = await _credentials.read();
    if (saved != null) {
      await _credentials.save(saved.copyWith(password: newPassword));
    }
  }

  // ---- Ghi nhớ tài khoản (đăng nhập nhanh) ----

  /// Tài khoản đã lưu trên máy này (null nếu chưa lưu).
  Future<SavedAccount?> savedAccount() => _credentials.read();

  Future<void> rememberAccount(SavedAccount account) =>
      _credentials.save(account);

  /// Bỏ lưu: lần sau phải nhập lại email + mật khẩu.
  Future<void> forgetAccount() => _credentials.clear();
}
