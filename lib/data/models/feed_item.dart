import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';
import 'author_model.dart';
import 'post_model.dart';

/// Một phần tử của bảng tin (`GET /activity-feeds`).
class FeedItem extends Equatable {
  final int feedId;
  final String targetType;
  final int targetId;

  /// CREATED_POST, PUBLISHED_LECTURE_VIDEO, SESSION_RESOLVED_APPROVED,
  /// EARNED_BADGE, REACHED_MILESTONE...
  final String actionType;
  final AuthorModel? actor;
  final Map<String, dynamic> content;
  final DateTime? createdAt;
  final int weight;

  /// Bài viết dựng sẵn ở client (vừa đăng xong, chưa có trong feed của server).
  final PostModel? localPost;

  const FeedItem({
    required this.feedId,
    required this.targetType,
    required this.targetId,
    required this.actionType,
    this.actor,
    this.content = const {},
    this.createdAt,
    this.weight = 0,
    this.localPost,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    final actor = J.asMap(json['actor']);
    return FeedItem(
      feedId: J.intOr(json['feed_id'] ?? json['id']),
      targetType: J.stringOr(json['target_type']),
      targetId: J.intOr(json['target_id']),
      actionType: J.stringOr(json['action_type']),
      actor: actor == null ? null : AuthorModel.fromJson(actor),
      content: J.asMap(json['content']) ?? const {},
      createdAt: J.asDate(json['created_at']),
      weight: J.intOr(json['weight']),
    );
  }

  /// Phần tử feed giả lập cho bài viết vừa đăng (hiện ngay đầu Bảng tin).
  factory FeedItem.fromPost(PostModel post) => FeedItem(
    feedId: -post.postId,
    targetType: 'POST',
    targetId: post.postId,
    actionType: 'CREATED_POST',
    actor: post.author,
    createdAt: post.createdAt,
    localPost: post,
  );

  bool get isPost => targetType.toUpperCase() == 'POST';

  FeedItem copyWith({PostModel? localPost}) => FeedItem(
    feedId: feedId,
    targetType: targetType,
    targetId: targetId,
    actionType: actionType,
    actor: actor,
    content: content,
    createdAt: createdAt,
    weight: weight,
    localPost: localPost ?? this.localPost,
  );

  /// Id bài viết nếu phần tử này là bài viết, ngược lại null.
  int? get postId => localPost?.postId ?? (isPost ? targetId : null);

  /// Dựng [PostModel] từ item (nếu là bài viết) để dùng chung PostCard.
  PostModel? toPost() {
    if (localPost != null) return localPost;
    if (!isPost) return null;
    final json = Map<String, dynamic>.from(content);
    // Dòng bảng tin chỉ chứa bản chụp rút gọn của bài: {title, media_url}.
    // Quy về định dạng bài viết đầy đủ để PostCard hiển thị được nội dung + ảnh.
    if ((json['content'] ?? json['text']) == null && json['title'] != null) {
      json['content'] = json['title'];
    }
    final mediaUrl = (json['media_url'] ?? '').toString();
    if (json['media_urls'] == null && mediaUrl.isNotEmpty) {
      final isVideo = RegExp(
        r'\.(mp4|mov|webm|mkv)(\?|$)',
        caseSensitive: false,
      ).hasMatch(mediaUrl);
      json['media_urls'] = [
        {'url': mediaUrl, 'type': isVideo ? 'VIDEO' : 'IMAGE'},
      ];
    }
    json['post_id'] ??= targetId;
    json['created_at'] ??= createdAt?.toIso8601String();
    if (json['author'] == null && actor != null) {
      json['author'] = actor!.toJson();
    }
    return PostModel.fromJson(json);
  }

  @override
  List<Object?> get props => [
    feedId,
    targetType,
    targetId,
    actionType,
    localPost,
  ];
}
