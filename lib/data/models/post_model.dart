import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';
import 'author_model.dart';
import 'media_item.dart';

enum PostType {
  socialPost,
  learningVideo,
  questionApprovedNotification,
  leaderboardHonor;

  static PostType parse(dynamic v) {
    switch (J.stringOr(v).toUpperCase()) {
      case 'LEARNING_VIDEO':
        return PostType.learningVideo;
      case 'QUESTION_APPROVED_NOTIFICATION':
        return PostType.questionApprovedNotification;
      case 'LEADERBOARD_HONOR':
        return PostType.leaderboardHonor;
      default:
        return PostType.socialPost;
    }
  }

  String get apiValue => switch (this) {
    PostType.socialPost => 'SOCIAL_POST',
    PostType.learningVideo => 'LEARNING_VIDEO',
    PostType.questionApprovedNotification => 'QUESTION_APPROVED_NOTIFICATION',
    PostType.leaderboardHonor => 'LEADERBOARD_HONOR',
  };
}

enum PostVisibility {
  public,
  friends,
  onlyMe;

  static PostVisibility parse(dynamic v) {
    switch (J.stringOr(v).toUpperCase()) {
      case 'FRIENDS':
        return PostVisibility.friends;
      case 'ONLY_ME':
        return PostVisibility.onlyMe;
      default:
        return PostVisibility.public;
    }
  }

  String get apiValue => switch (this) {
    PostVisibility.public => 'PUBLIC',
    PostVisibility.friends => 'FRIENDS',
    PostVisibility.onlyMe => 'ONLY_ME',
  };

  String get label => switch (this) {
    PostVisibility.public => 'Công khai',
    PostVisibility.friends => 'Bạn bè',
    PostVisibility.onlyMe => 'Chỉ mình tôi',
  };
}

/// Bài viết (`PostResponseDto`).
class PostModel extends Equatable {
  final int postId;
  final String content;
  final PostType postType;
  final List<MediaItem> media;
  final PostVisibility visibility;
  final AuthorModel author;
  final int reactCount;
  final int commentCount;
  final bool reactedByMe;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? lecturerNote;
  final DateTime? lecturerNoteAddedAt;
  final AuthorModel? notedLecturer;
  final int? subjectId;
  final String? subjectName;
  final String? subjectCode;
  final int? sessionId;

  const PostModel({
    required this.postId,
    this.content = '',
    this.postType = PostType.socialPost,
    this.media = const [],
    this.visibility = PostVisibility.public,
    required this.author,
    this.reactCount = 0,
    this.commentCount = 0,
    this.reactedByMe = false,
    this.createdAt,
    this.updatedAt,
    this.lecturerNote,
    this.lecturerNoteAddedAt,
    this.notedLecturer,
    this.subjectId,
    this.subjectName,
    this.subjectCode,
    this.sessionId,
  });

  /// Bài đã chỉnh sửa (updated_at muộn hơn created_at).
  bool get isEdited {
    if (createdAt == null || updatedAt == null) return false;
    return updatedAt!.difference(createdAt!).inSeconds > 1;
  }

  List<MediaItem> get images => media.where((m) => m.isImage).toList();
  List<MediaItem> get videos => media.where((m) => m.isVideo).toList();
  bool get hasSubject => (subjectName ?? subjectCode) != null;

  factory PostModel.fromJson(Map<String, dynamic> json) {
    final author = J.asMap(json['author']);
    final noted = J.asMap(json['noted_lecturer']);
    return PostModel(
      postId: J.intOr(json['post_id'] ?? json['id']),
      content: J.stringOr(json['content'] ?? json['text']),
      postType: PostType.parse(json['post_type']),
      media: J.list(json['media_urls'], MediaItem.fromJson),
      visibility: PostVisibility.parse(json['visibility']),
      author: author != null
          ? AuthorModel.fromJson(author)
          : const AuthorModel(userId: 0, fullName: 'Người dùng'),
      reactCount: J.intOr(json['react_count'] ?? json['like_count']),
      commentCount: J.intOr(json['comment_count']),
      reactedByMe: J.asBool(json['reacted_by_me']),
      createdAt: J.asDate(json['created_at']),
      updatedAt: J.asDate(json['updated_at']),
      lecturerNote: J.asString(json['lecturer_note']),
      lecturerNoteAddedAt: J.asDate(json['lecturer_note_added_at']),
      notedLecturer: noted == null ? null : AuthorModel.fromJson(noted),
      subjectId: J.asInt(json['subject_id']),
      subjectName: J.asString(json['subject_name']),
      subjectCode: J.asString(json['subject_code']),
      sessionId: J.asInt(json['session_id']),
    );
  }

  PostModel copyWith({
    String? content,
    List<MediaItem>? media,
    PostVisibility? visibility,
    int? reactCount,
    int? commentCount,
    bool? reactedByMe,
    DateTime? updatedAt,
  }) => PostModel(
    postId: postId,
    content: content ?? this.content,
    postType: postType,
    media: media ?? this.media,
    visibility: visibility ?? this.visibility,
    author: author,
    reactCount: reactCount ?? this.reactCount,
    commentCount: commentCount ?? this.commentCount,
    reactedByMe: reactedByMe ?? this.reactedByMe,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lecturerNote: lecturerNote,
    lecturerNoteAddedAt: lecturerNoteAddedAt,
    notedLecturer: notedLecturer,
    subjectId: subjectId,
    subjectName: subjectName,
    subjectCode: subjectCode,
    sessionId: sessionId,
  );

  @override
  List<Object?> get props => [
    postId,
    content,
    postType,
    media,
    visibility,
    author,
    reactCount,
    commentCount,
    reactedByMe,
    createdAt,
    updatedAt,
    lecturerNote,
    subjectId,
    sessionId,
  ];
}
