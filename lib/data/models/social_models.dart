import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';
import 'auth_session.dart';
import 'author_model.dart';

/// Một người bạn (`GET /friendships`).
class FriendModel extends Equatable {
  final int userId;
  final String fullName;
  final String? avatarUrl;
  final String? frameUrl;
  final DateTime? friendsSince;
  final int mutualFriendsCount;

  const FriendModel({
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    this.frameUrl,
    this.friendsSince,
    this.mutualFriendsCount = 0,
  });

  factory FriendModel.fromJson(Map<String, dynamic> json) => FriendModel(
    userId: J.intOr(json['user_id']),
    fullName: J.stringOr(json['full_name'], 'Người dùng'),
    avatarUrl: J.asString(json['avatar_url']),
    frameUrl: J.asString(json['frame_url']),
    friendsSince: J.asDate(json['friends_since']),
    mutualFriendsCount: J.intOr(json['mutual_friends_count']),
  );

  AuthorModel get asAuthor => AuthorModel(
    userId: userId,
    fullName: fullName,
    avatarUrl: avatarUrl,
    frameUrl: frameUrl,
  );

  @override
  List<Object?> get props => [userId, fullName, avatarUrl, mutualFriendsCount];
}

/// Lời mời kết bạn: nhận được (`requester`) hoặc đã gửi (`receiver`).
class FriendRequestModel extends Equatable {
  /// Người ở đầu kia của lời mời (người gửi nếu là lời mời nhận, người nhận
  /// nếu là lời mời đã gửi).
  final AuthorModel user;
  final bool sentByMe;
  final DateTime? createdAt;
  final int mutualFriendsCount;

  const FriendRequestModel({
    required this.user,
    required this.sentByMe,
    this.createdAt,
    this.mutualFriendsCount = 0,
  });

  factory FriendRequestModel.fromReceivedJson(Map<String, dynamic> json) =>
      FriendRequestModel(
        user: AuthorModel.fromJson(J.asMap(json['requester']) ?? const {}),
        sentByMe: false,
        createdAt: J.asDate(json['created_at']),
        mutualFriendsCount: J.intOr(json['mutual_friends_count']),
      );

  factory FriendRequestModel.fromSentJson(Map<String, dynamic> json) =>
      FriendRequestModel(
        user: AuthorModel.fromJson(J.asMap(json['receiver']) ?? const {}),
        sentByMe: true,
        createdAt: J.asDate(json['created_at']),
        mutualFriendsCount: J.intOr(json['mutual_friends_count']),
      );

  @override
  List<Object?> get props => [user, sentByMe, createdAt, mutualFriendsCount];
}

/// Người dùng trong kết quả tìm kiếm (`GET /search?type=USER`).
///
/// Server trả cả `email` của người khác trong kết quả tìm kiếm; app giữ lại
/// chỉ để đối chiếu khi tìm bằng email và KHÔNG hiển thị ra giao diện.
class UserSearchResult extends Equatable {
  final int userId;
  final String fullName;
  final String? code;
  final String? email;
  final String? bio;
  final String? avatarUrl;
  final String? frameUrl;
  final String? schoolFaculty;
  final String? major;
  final UserRole role;

  const UserSearchResult({
    required this.userId,
    required this.fullName,
    this.code,
    this.email,
    this.bio,
    this.avatarUrl,
    this.frameUrl,
    this.schoolFaculty,
    this.major,
    this.role = UserRole.student,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) =>
      UserSearchResult(
        userId: J.intOr(json['user_id']),
        fullName: J.stringOr(json['full_name'], 'Người dùng').trim(),
        code: J.asString(json['student_lecturer_code']),
        email: J.asString(json['email']),
        bio: J.asString(json['bio']),
        avatarUrl: J.asString(json['avatar_url']),
        frameUrl: J.asString(json['avatar_frame_url'] ?? json['frame_url']),
        schoolFaculty: J.asString(json['school_faculty']),
        major: J.asString(json['major']),
        role: UserRole.parse(json['role']),
      );

  /// Dòng phụ hiển thị dưới tên: "Mã · Khoa / Chuyên ngành".
  String get subtitle {
    final parts = <String>[
      if ((code ?? '').isNotEmpty) code!,
      if ((schoolFaculty ?? '').isNotEmpty)
        schoolFaculty!
      else if ((major ?? '').isNotEmpty)
        major!,
    ];
    return parts.isEmpty ? role.label : parts.join(' · ');
  }

  AuthorModel get asAuthor => AuthorModel(
    userId: userId,
    fullName: fullName,
    avatarUrl: avatarUrl,
    frameUrl: frameUrl,
  );

  @override
  List<Object?> get props => [userId, fullName, code, role];
}

/// Một trang kết quả tìm kiếm người dùng (phân trang theo offset `after`).
class UserSearchPage extends Equatable {
  final List<UserSearchResult> items;
  final int? nextOffset;
  final bool hasNext;
  final int totalHits;

  const UserSearchPage({
    this.items = const [],
    this.nextOffset,
    this.hasNext = false,
    this.totalHits = 0,
  });

  factory UserSearchPage.fromJson(dynamic data) {
    final map = J.asMap(data) ?? const <String, dynamic>{};
    final pagination = J.asMap(map['pagination']) ?? const <String, dynamic>{};
    final items = <UserSearchResult>[];
    for (final raw in J.asList(map['items'])) {
      final row = J.asMap(raw);
      final user = row == null ? null : J.asMap(row['user']);
      if (user != null) items.add(UserSearchResult.fromJson(user));
    }
    return UserSearchPage(
      items: items,
      nextOffset: J.asInt(pagination['after']),
      hasNext: J.asBool(pagination['has_next']),
      totalHits: J.intOr(map['total_hits']),
    );
  }

  @override
  List<Object?> get props => [items, nextOffset, hasNext, totalHits];
}
