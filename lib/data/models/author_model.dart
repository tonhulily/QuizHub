import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';

/// Thông tin rút gọn của người dùng, nhúng trong post / comment / feed...
class AuthorModel extends Equatable {
  final int userId;
  final String fullName;
  final String? avatarUrl;
  final String? frameUrl;

  const AuthorModel({
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    this.frameUrl,
  });

  factory AuthorModel.fromJson(Map<String, dynamic> json) => AuthorModel(
    userId: J.intOr(json['user_id'] ?? json['id']),
    fullName: J.stringOr(json['full_name'], 'Người dùng'),
    avatarUrl: J.asString(json['avatar_url']),
    frameUrl: J.asString(json['frame_url']),
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'full_name': fullName,
    'avatar_url': avatarUrl,
    'frame_url': frameUrl,
  };

  @override
  List<Object?> get props => [userId, fullName, avatarUrl, frameUrl];
}
