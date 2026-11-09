import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/comment_model.dart';
import '../media/media_viewer.dart';
import '../widgets/link_text.dart';
import '../widgets/blocked_content.dart';
import '../../data/models/media_item.dart';
import '../../core/design_system/app_icons.dart';

/// Một dòng bình luận (dùng cho cả bình luận gốc & phản hồi).
///
/// Quy tắc nghiệp vụ hiển thị:
/// - Bình luận bị ẩn (chặn / bị chặn / đã xoá): hiện "không khả dụng".
/// - Chỉ chủ bình luận mới có nút Xoá; KHÔNG ai được sửa.
class CommentTile extends StatelessWidget {
  final CommentModel comment;
  final bool isMine;
  final bool isReply;
  final bool liking;
  final VoidCallback? onLike;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final VoidCallback? onTapAuthor;

  const CommentTile({
    super.key,
    required this.comment,
    this.isMine = false,
    this.isReply = false,
    this.liking = false,
    this.onLike,
    this.onReply,
    this.onDelete,
    this.onReport,
    this.onTapAuthor,
  });

  @override
  Widget build(BuildContext context) => BlockedContent(
    userIds: [comment.author?.userId],
    blockedChild: const _UnavailableComment(),
    child: _content(context),
  );

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    final author = comment.author;

    if (comment.hidden || author == null) {
      return const _UnavailableComment();
    }

    final avatarSize = isReply ? 24.0 : 32.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            avatarUrl: author.avatarUrl,
            frameUrl: author.frameUrl,
            name: author.fullName,
            size: avatarSize,
            onTap: onTapAuthor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: isMine ? onDelete : onReport,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          author.fullName,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontSize: 13,
                          ),
                        ),
                        if ((comment.content ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: LinkText(
                              comment.content!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.4,
                              ),
                            ),
                          ),
                        if (comment.reactCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Semantics(
                              label: '${comment.reactCount} lượt thích',
                              excludeSemantics: true,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    AppIcons.likeFill,
                                    size: 13,
                                    color: AppColors.like,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    TimeFormat.compact(comment.reactCount),
                                    key: ValueKey(
                                      'comment_reaction_count_${comment.commentId}',
                                    ),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if ((comment.mediaUrl ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: GestureDetector(
                      onTap: () => MediaViewer.open(
                        context,
                        [MediaItem(url: comment.mediaUrl!)],
                        userIds: [comment.author!.userId],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: comment.mediaUrl!,
                          width: 160,
                          height: 160,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorWidget: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 6, top: 4),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        TimeFormat.ago(comment.createdAt),
                        style: theme.textTheme.bodySmall,
                      ),
                      if (onLike != null)
                        _TextAction(
                          label: 'Thích',
                          onTap: liking ? null : onLike,
                          color: comment.reactedByMe ? AppColors.like : null,
                          selected: comment.reactedByMe,
                        ),
                      if (onReply != null) ...[
                        _TextAction(label: 'Phản hồi', onTap: onReply!),
                      ],
                      if (isMine && onDelete != null) ...[
                        _TextAction(
                          label: 'Xoá',
                          onTap: onDelete!,
                          color: AppColors.error,
                        ),
                      ] else if (!isMine && onReport != null) ...[
                        _TextAction(label: 'Báo cáo', onTap: onReport!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnavailableComment extends StatelessWidget {
  const _UnavailableComment();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        const Icon(AppIcons.eyeOff, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: 8),
        Text(
          'Bình luận này không khả dụng',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    ),
  );
}

class _TextAction extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final bool? selected;

  const _TextAction({
    required this.label,
    required this.onTap,
    this.color,
    this.selected,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    selected: selected,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: color ?? AppColors.textSecondary,
          ),
        ),
      ),
    ),
  );
}
