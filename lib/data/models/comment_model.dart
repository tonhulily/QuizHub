import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';
import 'author_model.dart';

/// Đối tượng được bình luận / thả cảm xúc.
enum TargetType {
  post,
  session,
  question;

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
      hidden: J.asBool(json['hidden']),
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
      default:
        return null;
    }
  }

  CommentModel copyWith({
    int? replyCount,
    List<CommentModel>? replies,
    bool? hidden,
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
    replyCount,
    replies,
  ];
}
