import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';
import 'auth_session.dart';
import 'author_model.dart';

enum Gender {
  male,
  female;

  static Gender? parse(dynamic v) {
    switch (J.stringOr(v).toUpperCase()) {
      case 'MALE':
        return Gender.male;
      case 'FEMALE':
        return Gender.female;
      default:
        return null;
    }
  }

  String get apiValue => name.toUpperCase();
  String get label => this == Gender.male ? 'Nam' : 'Nữ';
}

/// Quan hệ giữa mình và người đang xem (có trong `GET /users/{id}`).
class RelationshipModel extends Equatable {
  final bool isFriend;
  final bool isFollowing;
  final bool isFollowed;

  /// NONE / PENDING / ACCEPTED / DECLINED
  final String friendRequestStatus;

  const RelationshipModel({
    this.isFriend = false,
    this.isFollowing = false,
    this.isFollowed = false,
    this.friendRequestStatus = 'NONE',
  });

  RelationshipModel copyWith({
    bool? isFriend,
    bool? isFollowing,
    bool? isFollowed,
    String? friendRequestStatus,
  }) => RelationshipModel(
    isFriend: isFriend ?? this.isFriend,
    isFollowing: isFollowing ?? this.isFollowing,
    isFollowed: isFollowed ?? this.isFollowed,
    friendRequestStatus: friendRequestStatus ?? this.friendRequestStatus,
  );

  factory RelationshipModel.fromJson(Map<String, dynamic> json) =>
      RelationshipModel(
        isFriend: J.asBool(json['is_friend']),
        isFollowing: J.asBool(json['is_following']),
        isFollowed: J.asBool(json['is_followed']),
        friendRequestStatus: J.stringOr(json['friend_request_status'], 'NONE'),
      );

  @override
  List<Object?> get props => [
    isFriend,
    isFollowing,
    isFollowed,
    friendRequestStatus,
  ];
}

/// Hồ sơ người dùng (`GET /users/me`, `GET /users/{id}`).
class ProfileModel extends Equatable {
  final int userId;
  final String? email;
  final String fullName;
  final String? avatarUrl;
  final String? coverUrl;
  final String? frameUrl;
  final Gender? gender;
  final DateTime? dateOfBirth;
  final String? bio;
  final String? schoolFaculty;
  final String? major;
  final String? className;
  final String? studentLecturerCode;
  final UserRole role;
  final String? timezone;
  final bool profileCompleted;
  final bool verified;
  final int totalProposedQuestions;
  final double gamificationPoints;
  final int badgesCount;
  final int friendsCount;
  final int followersCount;
  final int followingCount;
  final DateTime? createdAt;
  final RelationshipModel? relationships;

  const ProfileModel({
    required this.userId,
    this.email,
    required this.fullName,
    this.avatarUrl,
    this.coverUrl,
    this.frameUrl,
    this.gender,
    this.dateOfBirth,
    this.bio,
    this.schoolFaculty,
    this.major,
    this.className,
    this.studentLecturerCode,
    this.role = UserRole.student,
    this.timezone,
    this.profileCompleted = true,
    this.verified = true,
    this.totalProposedQuestions = 0,
    this.gamificationPoints = 0,
    this.badgesCount = 0,
    this.friendsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.createdAt,
    this.relationships,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final rel = J.asMap(json['relationships']);
    return ProfileModel(
      userId: J.intOr(json['user_id'] ?? json['id']),
      email: J.asString(json['email']),
      fullName: J.stringOr(json['full_name']),
      avatarUrl: J.asString(json['avatar_url']),
      coverUrl: J.asString(json['cover_url']),
      frameUrl: J.asString(json['frame_url']),
      gender: Gender.parse(json['gender']),
      dateOfBirth: J.asDate(json['date_of_birth']),
      bio: J.asString(json['bio']),
      schoolFaculty: J.asString(json['school_faculty']),
      major: J.asString(json['major']),
      className: J.asString(json['class_name']),
      studentLecturerCode: J.asString(json['student_lecturer_code']),
      role: UserRole.parse(json['role']),
      timezone: J.asString(json['timezone']),
      profileCompleted: J.asBool(json['profile_completed'], true),
      verified: J.asBool(json['verified'], true),
      totalProposedQuestions: J.intOr(json['total_proposed_questions']),
      gamificationPoints: J.asDouble(json['gamification_points']) ?? 0,
      badgesCount: J.intOr(json['badges_count']),
      friendsCount: J.intOr(json['friends_count']),
      followersCount: J.intOr(json['followers_count']),
      followingCount: J.intOr(json['following_count']),
      createdAt: J.asDate(json['created_at']),
      relationships: rel == null ? null : RelationshipModel.fromJson(rel),
    );
  }

  /// Dùng để cache cục bộ (không gồm `relationships`).
  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'email': email,
    'full_name': fullName,
    'avatar_url': avatarUrl,
    'cover_url': coverUrl,
    'frame_url': frameUrl,
    'gender': gender?.apiValue,
    'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
    'bio': bio,
    'school_faculty': schoolFaculty,
    'major': major,
    'class_name': className,
    'student_lecturer_code': studentLecturerCode,
    'role': role.name.toUpperCase(),
    'timezone': timezone,
    'profile_completed': profileCompleted,
    'verified': verified,
    'total_proposed_questions': totalProposedQuestions,
    'gamification_points': gamificationPoints,
    'badges_count': badgesCount,
    'friends_count': friendsCount,
    'followers_count': followersCount,
    'following_count': followingCount,
    'created_at': createdAt?.toIso8601String(),
  };

  /// Dạng rút gọn để hiển thị (vd đặt làm tác giả khi vừa đăng bài).
  AuthorModel toAuthor() => AuthorModel(
    userId: userId,
    fullName: fullName,
    avatarUrl: avatarUrl,
    frameUrl: frameUrl,
  );

  @override
  List<Object?> get props => [
    userId,
    email,
    fullName,
    avatarUrl,
    coverUrl,
    frameUrl,
    gender,
    dateOfBirth,
    bio,
    schoolFaculty,
    major,
    className,
    studentLecturerCode,
    role,
    profileCompleted,
    verified,
    totalProposedQuestions,
    gamificationPoints,
    badgesCount,
    friendsCount,
    followersCount,
    followingCount,
    relationships,
  ];
}
