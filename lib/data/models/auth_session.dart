import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';

enum UserRole {
  student,
  lecturer,
  admin;

  static UserRole parse(dynamic v) {
    switch (J.stringOr(v).toUpperCase()) {
      case 'ADMIN':
        return UserRole.admin;
      case 'LECTURER':
        return UserRole.lecturer;
      default:
        return UserRole.student;
    }
  }

  String get label => switch (this) {
    UserRole.student => 'Sinh viên',
    UserRole.lecturer => 'Giảng viên',
    UserRole.admin => 'Quản trị viên',
  };

  bool get isLecturer => this == UserRole.lecturer || this == UserRole.admin;
}

/// Kết quả `POST /auth/login`.
class AuthSession extends Equatable {
  final int userId;
  final String username;
  final UserRole role;
  final String accessToken;
  final String refreshToken;
  final String? avatarUrl;
  final String? coverUrl;
  final String? frameUrl;
  final bool verified;
  final bool profileCompleted;

  const AuthSession({
    required this.userId,
    required this.username,
    required this.role,
    required this.accessToken,
    required this.refreshToken,
    this.avatarUrl,
    this.coverUrl,
    this.frameUrl,
    this.verified = true,
    this.profileCompleted = true,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    userId: J.intOr(json['user_id'] ?? json['id']),
    username: J.stringOr(json['username']),
    role: UserRole.parse(json['role']),
    accessToken: J.stringOr(json['access_token']),
    refreshToken: J.stringOr(json['refresh_token']),
    avatarUrl: J.asString(json['avatar_url']),
    coverUrl: J.asString(json['cover_url']),
    frameUrl: J.asString(json['frame_url']),
    verified: J.asBool(json['verified'], true),
    profileCompleted: J.asBool(json['profile_completed'], true),
  );

  @override
  List<Object?> get props => [userId, username, role, accessToken];
}
