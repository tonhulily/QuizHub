import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/component_tokens.dart';
import '../../core/design_system/design_tokens.dart';
import '../../core/network/api_exception.dart';
import '../../core/router/app_routes.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/fb_widgets.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/comment_model.dart';
import '../../data/models/post_model.dart';
import '../../data/repositories/post_repository.dart';
import '../../data/repositories/reaction_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../di/locator.dart';
import '../../features/profile/cubit/profile_cubit.dart';
import '../comment/comments_sheet.dart';
import '../report/report_sheet.dart';
import '../widgets/expandable_text.dart';
import 'post_media_grid.dart';
import '../../core/design_system/app_icons.dart';

/// Thẻ bài viết dùng chung (Home, Profile, Search, Video...).
///
/// Tự xử lý: Like (optimistic), mở Bình luận, xem ảnh/video, xoá bài (chủ bài),
/// báo cáo (người khác). Cha chỉ cần truyền [post] và (tuỳ chọn) các callback:
///
/// ```dart
/// PostCard(
///   post: post,
///   onChanged: (p) => ...thay thế post trong list,
///   onDeleted: (p) => ...bỏ post khỏi list,
///   onEdit: (p) => Navigator.pushNamed(context, AppRoutes.editPost, arguments: p),
/// )
/// ```
class PostCard extends StatefulWidget {
  final PostModel post;
  final ValueChanged<PostModel>? onChanged;
  final ValueChanged<PostModel>? onDeleted;
  final ValueChanged<PostModel>? onEdit;

  /// Bấm vào thân bài (mặc định không làm gì; Home có thể mở chi tiết)
  final ValueChanged<PostModel>? onTap;

  /// Ghi đè hành vi bấm vào tác giả (mặc định mở trang cá nhân)
  final ValueChanged<PostModel>? onTapAuthor;

  /// Nút "Chia sẻ". Mặc định báo "đang phát triển" cho tới khi có module chia sẻ.
  final ValueChanged<PostModel>? onShare;

  const PostCard({
    super.key,
    required this.post,
    this.onChanged,
    this.onDeleted,
    this.onEdit,
    this.onTap,
    this.onTapAuthor,
    this.onShare,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late PostModel _post = widget.post;
  bool _likeBusy = false;
  bool _removed = false;

  @override
  void didUpdateWidget(covariant PostCard old) {
    super.didUpdateWidget(old);
    if (old.post != widget.post) _post = widget.post;
  }

  void _update(PostModel p) {
    setState(() => _post = p);
    widget.onChanged?.call(p);
  }

  bool get _isMine =>
      context.read<ProfileCubit>().state.profile?.userId == _post.author.userId;

  // ---------------- Like ----------------
  Future<void> _toggleLike() async {
    if (_likeBusy) return;
    _likeBusy = true;
    final before = _post;
    final nextReacted = !before.reactedByMe;
    // Optimistic UI
    _update(
      before.copyWith(
        reactedByMe: nextReacted,
        reactCount: (before.reactCount + (nextReacted ? 1 : -1)).clamp(
          0,
          1 << 30,
        ),
      ),
    );
    try {
      final result = await getIt<ReactionRepository>().toggleLike(
        targetType: TargetType.post,
        targetId: before.postId,
      );
      if (!mounted) return;
      _update(
        _post.copyWith(
          reactedByMe: result.reacted,
          reactCount: result.totalCount,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _update(before); // hoàn tác
      AppFeedback.error(context, e);
    } finally {
      _likeBusy = false;
    }
  }

  // ---------------- Comment ----------------
  void _openComments() {
    showCommentsSheet(
      context,
      targetType: TargetType.post,
      targetId: _post.postId,
      onCountChanged: (delta) {
        if (!mounted) return;
        _update(
          _post.copyWith(
            commentCount: (_post.commentCount + delta).clamp(0, 1 << 30),
          ),
        );
      },
    );
  }

  // ---------------- Delete / Report ----------------
  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Xoá bài viết',
      message: 'Bài viết sẽ bị xoá vĩnh viễn. Bạn có chắc không?',
      confirmLabel: 'Xoá',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      final deletedNow = await AppFeedback.withLoading(
        () => getIt<PostRepository>().delete(_post.postId),
      );
      if (!mounted) return;
      setState(() => _removed = true);
      widget.onDeleted?.call(_post);
      if (deletedNow) {
        AppFeedback.success(context, 'Đã xoá bài viết');
      } else {
        // Bài đã bị xoá từ trước (server báo không tìm thấy) -> chỉ gỡ khỏi danh sách
        AppFeedback.info(
          context,
          'Bài viết này đã bị xoá trước đó, đã gỡ khỏi danh sách.',
        );
      }
    } on ApiException catch (e) {
      if (mounted) AppFeedback.error(context, e);
    }
  }

  void _openAuthor() {
    if (widget.onTapAuthor != null) {
      widget.onTapAuthor!(_post);
      return;
    }
    Navigator.of(context).pushNamed(
      _isMine ? AppRoutes.myProfile : AppRoutes.userProfile,
      arguments: _post.author.userId,
    );
  }

  void _showMenu() {
    final mine = _isMine;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mine && widget.onEdit != null)
              ListTile(
                leading: const Icon(AppIcons.edit),
                title: const Text('Chỉnh sửa bài viết'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onEdit!(_post);
                },
              ),
            if (mine)
              ListTile(
                leading: const Icon(AppIcons.delete, color: AppColors.error),
                title: const Text(
                  'Xoá bài viết',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _delete();
                },
              )
            else
              ListTile(
                leading: const Icon(AppIcons.flag),
                title: const Text('Báo cáo bài viết'),
                onTap: () {
                  Navigator.pop(ctx);
                  showReportSheet(
                    context,
                    target: ReportTarget.post,
                    targetId: _post.postId,
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---------------- Build ----------------
  @override
  Widget build(BuildContext context) {
    if (_removed) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final p = _post;

    // Kiểu Facebook: khối trắng tràn cạnh, không bo góc, không đổ bóng;
    // khoảng xám giữa các bài do danh sách chèn (PagedListView.itemSpacing).
    return Container(
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme, p),
          if (p.content.trim().isNotEmpty || p.hasSubject)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap == null ? null : () => widget.onTap!(p),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.hasSubject) ...[
                      _SubjectChip(
                        label: [
                          if (p.subjectCode != null) p.subjectCode!,
                          if (p.subjectName != null) p.subjectName!,
                        ].join(' · '),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (p.content.trim().isNotEmpty)
                      ExpandableText(
                        p.content,
                        maxLines: ComponentTokens.postCollapsedLines,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 15,
                          height: 1.35,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          // Ảnh/video tràn hết chiều ngang như Facebook
          if (p.media.isNotEmpty) PostMediaGrid(media: p.media),
          if ((p.lecturerNote ?? '').isNotEmpty) _LecturerNote(post: p),
          _buildCounts(theme, p),
          const Divider(indent: 12, endIndent: 12, height: 1),
          _buildActions(p),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, PostModel p) {
    final meta = <String>[
      TimeFormat.ago(p.createdAt),
      if (p.isEdited) 'Đã chỉnh sửa',
    ].where((e) => e.isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
      child: Row(
        children: [
          UserAvatar(
            avatarUrl: p.author.avatarUrl,
            frameUrl: p.author.frameUrl,
            name: p.author.fullName,
            onTap: _openAuthor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openAuthor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.author.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('·', style: theme.textTheme.bodySmall),
                      const SizedBox(width: 4),
                      Icon(
                        switch (p.visibility) {
                          PostVisibility.public => AppIcons.audienceEveryone,
                          PostVisibility.friends => AppIcons.audienceFriends,
                          PostVisibility.onlyMe => AppIcons.audienceOnlyMe,
                        },
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(AppIcons.more),
            color: AppColors.textSecondary,
            onPressed: _showMenu,
          ),
        ],
      ),
    );
  }

  Widget _buildCounts(ThemeData theme, PostModel p) {
    if (p.reactCount == 0 && p.commentCount == 0) {
      return const SizedBox(height: 4);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Row(
        children: [
          if (p.reactCount > 0) ...[
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: AppColors.like,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                AppIcons.likeFill,
                size: 14,
                color: AppColors.white,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              TimeFormat.compact(p.reactCount),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const Spacer(),
          if (p.commentCount > 0)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openComments,
              child: Text(
                '${TimeFormat.compact(p.commentCount)} bình luận',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions(PostModel p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: p.reactedByMe ? AppIcons.likeFill : AppIcons.like,
              label: 'Thích',
              color: p.reactedByMe ? AppColors.like : AppColors.textSecondary,
              onTap: _toggleLike,
            ),
          ),
          Expanded(
            child: _ActionButton(
              icon: AppIcons.comment,
              label: 'Bình luận',
              color: AppColors.textSecondary,
              onTap: _openComments,
            ),
          ),
          Expanded(
            child: _ActionButton(
              icon: AppIcons.share,
              label: 'Chia sẻ',
              color: AppColors.textSecondary,
              // Chia sẻ bài viết chưa có API -> module sau thay bằng onShare
              onTap: widget.onShare == null
                  ? () => showComingSoon(context, 'Chia sẻ bài viết')
                  : () => widget.onShare!(_post),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
      onTap: onTap,
      child: SizedBox(
        height: 40,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: DesignTokens.animFast,
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(icon, key: ValueKey(icon), size: 24, color: color),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  final String label;
  const _SubjectChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondary100,
        borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(AppIcons.subject, size: 15, color: AppColors.secondary700),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.secondary800),
            ),
          ),
        ],
      ),
    );
  }
}

class _LecturerNote extends StatelessWidget {
  final PostModel post;
  const _LecturerNote({required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondary50,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        border: Border.all(color: AppColors.secondary200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                AppIcons.schoolFill,
                size: 18,
                color: AppColors.secondary700,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  post.notedLecturer == null
                      ? 'Ghi chú của giảng viên'
                      : 'Ghi chú của ${post.notedLecturer!.fullName}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.secondary800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(post.lecturerNote!, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
