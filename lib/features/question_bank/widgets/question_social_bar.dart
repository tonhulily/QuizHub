import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../data/models/comment_model.dart';
import '../../../data/repositories/like_state_store.dart';
import '../../../data/repositories/reaction_repository.dart';
import '../../../di/locator.dart';
import '../../../shared/comment/comments_sheet.dart';
import '../../profile/cubit/profile_cubit.dart';

/// Thích / Bình luận một câu hỏi (giống bài viết): số đếm lấy từ API, bình
/// luận mở khung bình luận dùng chung của bài viết.
///
/// Backend không cho biết "mình đã thích chưa" lúc mở màn hình, nên trạng thái
/// nút lấy từ lần bấm gần nhất lưu trên máy ([LikeStateStore]); nút chỉ đổi
/// khi server đã trả lời, không đổi trước.
class QuestionSocialBar extends StatefulWidget {
  final int questionId;
  final int reactCount;
  final int commentCount;
  final bool reactedByMe;

  const QuestionSocialBar({
    super.key,
    required this.questionId,
    this.reactCount = 0,
    this.commentCount = 0,
    this.reactedByMe = false,
  });

  @override
  State<QuestionSocialBar> createState() => _QuestionSocialBarState();
}

class _QuestionSocialBarState extends State<QuestionSocialBar> {
  late final int? _userId = context.read<ProfileCubit>().state.profile?.userId;
  late bool _reacted = _remembered();
  late int _reacts = widget.reactCount;
  late int _comments = widget.commentCount;
  bool _likeBusy = false;

  bool _remembered() {
    final id = _userId;
    final saved = id == null
        ? null
        : getIt<LikeStateStore>().get(
            id,
            TargetType.question,
            widget.questionId,
          );
    return widget.reactedByMe || (saved ?? false);
  }

  @override
  void didUpdateWidget(covariant QuestionSocialBar old) {
    super.didUpdateWidget(old);
    if (old.reactCount != widget.reactCount ||
        old.commentCount != widget.commentCount ||
        old.reactedByMe != widget.reactedByMe) {
      _reacted = _remembered();
      _reacts = widget.reactCount;
      _comments = widget.commentCount;
    }
  }

  Future<void> _toggleLike() async {
    if (_likeBusy) return;
    setState(() => _likeBusy = true);
    try {
      final r = await getIt<ReactionRepository>().toggleLike(
        targetType: TargetType.question,
        targetId: widget.questionId,
      );
      final id = _userId;
      if (id != null) {
        await getIt<LikeStateStore>().set(
          id,
          TargetType.question,
          widget.questionId,
          r.reacted,
        );
      }
      if (!mounted) return;
      setState(() {
        _reacted = r.reacted;
        _reacts = r.totalCount;
      });
    } on ApiException catch (e) {
      if (mounted) AppFeedback.error(context, e);
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  void _openComments() => showCommentsSheet(
    context,
    targetType: TargetType.question,
    targetId: widget.questionId,
    onCountChanged: (delta) {
      if (mounted) {
        setState(() => _comments = (_comments + delta).clamp(0, 1 << 30));
      }
    },
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
    );
    Widget action(
      IconData icon,
      String label,
      Color color,
      VoidCallback? onTap,
    ) => Expanded(
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: color),
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_reacts > 0 || _comments > 0) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (_reacts > 0) Text('$_reacts lượt thích', style: muted),
              const Spacer(),
              if (_comments > 0)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openComments,
                  child: Text('$_comments bình luận', style: muted),
                ),
            ],
          ),
        ],
        const SizedBox(height: 4),
        const Divider(height: 1),
        Row(
          children: [
            action(
              _reacted ? AppIcons.likeFill : AppIcons.like,
              'Thích',
              _reacted ? AppColors.like : AppColors.textSecondary,
              _likeBusy ? null : _toggleLike,
            ),
            action(
              AppIcons.comment,
              'Bình luận',
              AppColors.textSecondary,
              _openComments,
            ),
          ],
        ),
      ],
    );
  }
}