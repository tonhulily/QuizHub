import 'dart:convert';

import 'package:equatable/equatable.dart';

/// Tài khoản người dùng chọn "Lưu thông tin đăng nhập" trên máy này.
///
/// Chỉ được lưu trong kho bảo mật của hệ điều hành (Android Keystore / iOS
/// Keychain) - xem `CredentialStorage`. `fullName` / `avatarUrl` chỉ để hiển
/// thị thẻ "Tiếp tục với ..." ở màn Đăng nhập.
class SavedAccount extends Equatable {
  final String email;
  final String password;
  final String? fullName;
  final String? avatarUrl;

  const SavedAccount({
    required this.email,
    required this.password,
    this.fullName,
    this.avatarUrl,
  });

  /// Tên hiển thị: họ tên nếu có, không thì email.
  String get displayName =>
      (fullName ?? '').trim().isNotEmpty ? fullName!.trim() : email;

  SavedAccount copyWith({
    String? password,
    String? fullName,
    String? avatarUrl,
  }) => SavedAccount(
    email: email,
    password: password ?? this.password,
    fullName: fullName ?? this.fullName,
    avatarUrl: avatarUrl ?? this.avatarUrl,
  );

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'full_name': fullName,
    'avatar_url': avatarUrl,
  };

  String encode() => jsonEncode(toJson());

  /// Trả về null nếu dữ liệu hỏng / thiếu email hoặc mật khẩu.
  static SavedAccount? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final email = map['email']?.toString() ?? '';
      final password = map['password']?.toString() ?? '';
      if (email.isEmpty || password.isEmpty) return null;
      return SavedAccount(
        email: email,
        password: password,
        fullName: map['full_name']?.toString(),
        avatarUrl: map['avatar_url']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [email, password, fullName, avatarUrl];
}
