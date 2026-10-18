import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/models/saved_account.dart';

/// Lưu tài khoản + mật khẩu người dùng chọn ghi nhớ, trong Keychain / Keystore
/// (cùng kho với [TokenStorage]). KHÔNG bao giờ ghi vào SharedPreferences.
///
/// Khác token: dữ liệu này được GIỮ LẠI khi đăng xuất (mục đích là lần sau chỉ
/// cần bấm một lần để vào). Chỉ bị xoá khi người dùng chủ động bỏ lưu hoặc khi
/// mật khẩu đã lưu không còn đúng.
class CredentialStorage {
  static const _kAccount = 'saved_account';

  final FlutterSecureStorage _storage;

  CredentialStorage([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  Future<SavedAccount?> read() async {
    try {
      return SavedAccount.decode(await _storage.read(key: _kAccount));
    } catch (_) {
      // Keystore hỏng (vd restore backup) -> coi như chưa lưu
      await clear();
      return null;
    }
  }

  Future<void> save(SavedAccount account) async {
    try {
      await _storage.write(key: _kAccount, value: account.encode());
    } catch (_) {
      // Không lưu được thì thôi: người dùng vẫn đăng nhập bình thường
    }
  }

  /// Cập nhật tên / ảnh hiển thị nếu đang lưu đúng tài khoản [email].
  Future<void> updateProfile({
    required String email,
    String? fullName,
    String? avatarUrl,
  }) async {
    final saved = await read();
    if (saved == null || saved.email.toLowerCase() != email.toLowerCase()) {
      return;
    }
    await save(saved.copyWith(fullName: fullName, avatarUrl: avatarUrl));
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _kAccount);
    } catch (_) {}
  }
}
