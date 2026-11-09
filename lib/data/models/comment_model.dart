import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';
import 'author_model.dart';

/// Đối tượng được bình luận / thả cảm xúc.
enum TargetType {
  post,
  session,
  question,
  comment;

  String get apiValue => name.toUpperCase();
}

/// Bình luận (`CommentResponseDto`).
class CommentModel extends Equatable {
  final int commentId;
  final TargetType? targetType;
  final int? targetId;
  final int? parentCommentId;

  /// null khi bị ẩn (do chặn / bị chặn / đã xoá)
  final String? content;
  final String? mediaUrl;

  /// null khi [hidden]
  final AuthorModel? author;
  final DateTime? createdAt;
  final bool hidden;
  final int reactCount;
  final bool reactedByMe;
  final int replyCount;
  final List<CommentModel> replies;

  const CommentModel({
    required this.commentId,
    this.targetType,
    this.targetId,
    this.parentCommentId,
    this.content,
    this.mediaUrl,
    this.author,
    this.createdAt,
    this.hidden = false,
    this.reactCount = 0,
    this.reactedByMe = false,
    this.replyCount = 0,
    this.replies = const [],
  });

  bool get isReply => parentCommentId != null;

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final author = J.asMap(json['author']);
    final replies = J.list(json['replies'], CommentModel.fromJson);
    return CommentModel(
      commentId: J.intOr(json['comment_id'] ?? json['id']),
      targetType: _parseTarget(json['target_type']),
      targetId: J.asInt(json['target_id']),
      parentCommentId: J.asInt(json['parent_comment_id']),
      content: J.asString(json['content']),
      mediaUrl: J.asString(json['media_url']),
      author: author == null ? null : AuthorModel.fromJson(author),
      createdAt: J.asDate(json['created_at']),
      hidden: J.asBool(json['hidden']) || J.asBool(json['deleted']),
      reactCount:
          J.asInt(
            json['react_count'] ?? json['like_count'] ?? json['total_count'],
          ) ??
          J.intOr(J.asMap(json['reaction_counts'])?['LIKE']),
      reactedByMe: J.asBool(
        json['reacted_by_me'],
        J.asString(json['my_reaction']) != null &&
            J.stringOr(json['my_reaction']).toUpperCase() != 'NONE',
      ),
      replyCount: J.asInt(json['reply_count']) ?? replies.length,
      replies: replies,
    );
  }

  static TargetType? _parseTarget(dynamic v) {
    switch (J.stringOr(v).toUpperCase()) {
      case 'POST':
        return TargetType.post;
      case 'SESSION':
        return TargetType.session;
      case 'QUESTION':
        return TargetType.question;
      case 'COMMENT':
        return TargetType.comment;
      default:
        return null;
    }
  }

  CommentModel copyWith({
    int? replyCount,
    List<CommentModel>? replies,
    bool? hidden,
    int? reactCount,
    bool? reactedByMe,
  }) => CommentModel(
    commentId: commentId,
    targetType: targetType,
    targetId: targetId,
    parentCommentId: parentCommentId,
    content: content,
    mediaUrl: mediaUrl,
    author: author,
    createdAt: createdAt,
    hidden: hidden ?? this.hidden,
    reactCount: reactCount ?? this.reactCount,
    reactedByMe: reactedByMe ?? this.reactedByMe,
    replyCount: replyCount ?? this.replyCount,
    replies: replies ?? this.replies,
  );

  @override
  List<Object?> get props => [
    commentId,
    parentCommentId,
    content,
    mediaUrl,
    author,
    hidden,
    reactCount,
    reactedByMe,
    replyCount,
    replies,
  ];
}
