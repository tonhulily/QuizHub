import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/component_tokens.dart';
import '../../core/router/app_routes.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/comment_model.dart';
import '../../data/repositories/comment_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../di/locator.dart';
import '../../features/profile/cubit/profile_cubit.dart';
import '../report/report_sheet.dart';
import 'comment_tile.dart';
import 'comments_cubit.dart';
import '../../core/design_system/app_icons.dart';

/// Mở bottom sheet bình luận cho một đối tượng.
///
/// [onCountChanged] nhận chênh lệch số bình luận (cộng/trừ) khi đóng sheet,
/// dùng để cập nhật số đếm trên PostCard mà không cần gọi lại API.
Future<void> showCommentsSheet(
  BuildContext context, {
  required TargetType targetType,
  required int targetId,
  void Function(int delta)? onCountChanged,
}) async {
  // Lấy ProfileCubit trước (sheet nằm trên Overlay khác nhưng vẫn kế thừa context)
  final delta = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(ComponentTokens.bottomSheetRadius),
      ),
    ),
    builder: (sheetContext) => BlocProvider(
      create: (_) => CommentsCubit(
        getIt<CommentRepository>(),
        targetType: targetType,
        targetId: targetId,
      )..load(),
      child: FractionallySizedBox(
        heightFactor: 0.88,
        child: const _CommentsSheet(),
      ),
    ),
  );
  if (delta != null && delta != 0) onCountChanged?.call(delta);
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet();

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final _focus = FocusNode();
  String? _inputError;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        context.read<CommentsCubit>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    if (Validators.wordCount(text) > ComponentTokens.maxCommentWords) {
      setState(
        () => _inputError =
            'Bình luận tối đa ${ComponentTokens.maxCommentWords} từ.',
      );
      return;
    }
    setState(() => _inputError = null);
    final error = await context.read<CommentsCubit>().send(text);
    if (!mounted) return;
    if (error != null) {
      AppFeedback.error(context, error);
    } else {
      _input.clear();
      _focus.unfocus();
    }
  }

  Future<void> _delete(CommentModel c) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Xoá bình luận',
      message: 'Bạn có chắc muốn xoá bình luận này?',
      confirmLabel: 'Xoá',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final error = await context.read<CommentsCubit>().delete(c);
    if (error != null && mounted) AppFeedback.error(context, error);
  }

  void _openAuthor(CommentModel c) {
    final id = c.author?.userId;
    if (id == null) return;
    final myId = context.read<ProfileCubit>().state.profile?.userId;
    Navigator.of(context).pushNamed(
      id == myId ? AppRoutes.myProfile : AppRoutes.userProfile,
      arguments: id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<CommentsCubit>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(cubit.state.countDelta);
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            // Header
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.neutral200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Bình luận',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: BlocBuilder<CommentsCubit, CommentsState>(
                builder: (context, state) {
                  switch (state.status) {
                    case CommentsStatus.loading:
                      return const LoadingView();
                    case CommentsStatus.failure:
                      return ErrorView(
                        error: state.error,
                        compact: true,
                        onRetry: cubit.load,
                      );
                    case CommentsStatus.loaded:
                      if (state.items.isEmpty) {
                        return const EmptyView(
                          icon: AppIcons.comment,
                          title: 'Chưa có bình luận',
                          message: 'Hãy là người đầu tiên bình luận.',
                          compact: true,
                        );
                      }
                      return _buildList(state);
                  }
                },
              ),
            ),
            _buildInput(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildList(CommentsState state) {
    final myId = context.read<ProfileCubit>().state.profile?.userId;
    final cubit = context.read<CommentsCubit>();

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: state.items.length + (state.loadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= state.items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          );
        }
        final c = state.items[i];
        final thread = state.threads[c.commentId];
        final loadedReplies = thread?.items ?? const <CommentModel>[];
        final remaining = c.replyCount - loadedReplies.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CommentTile(
              comment: c,
              isMine: c.author?.userId == myId,
              onReply: () {
                cubit.startReply(c);
                _focus.requestFocus();
              },
              onDelete: () => _delete(c),
              onReport: () => showReportSheet(
                context,
                target: ReportTarget.comment,
                targetId: c.commentId,
              ),
              onTapAuthor: () => _openAuthor(c),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 46),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in loadedReplies)
                    CommentTile(
                      comment: r,
                      isReply: true,
                      isMine: r.author?.userId == myId,
                      onReply: () {
                        cubit.startReply(r);
                        _focus.requestFocus();
                      },
                      onDelete: () => _delete(r),
                      onReport: () => showReportSheet(
                        context,
                        target: ReportTarget.comment,
                        targetId: r.commentId,
                      ),
                      onTapAuthor: () => _openAuthor(r),
                    ),
                  if (thread?.loading ?? false)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (remaining > 0 || (thread?.hasNext ?? false))
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => cubit.loadReplies(c),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          loadedReplies.isEmpty
                              ? 'Xem ${c.replyCount} phản hồi'
                              : 'Xem thêm phản hồi',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInput(ThemeData theme) {
    return BlocBuilder<CommentsCubit, CommentsState>(
      buildWhen: (a, b) =>
          a.replyingTo != b.replyingTo || a.sending != b.sending,
      builder: (context, state) {
        final replying = state.replyingTo;
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          padding: EdgeInsets.fromLTRB(
            12,
            8,
            12,
            8 + MediaQuery.paddingOf(context).bottom * 0.5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (replying != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Đang trả lời ${replying.author?.fullName ?? ''}',
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: context.read<CommentsCubit>().cancelReply,
                        child: const Icon(
                          AppIcons.close,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Builder(
                    builder: (context) {
                      final me = context.read<ProfileCubit>().state.profile;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6, right: 8),
                        child: UserAvatar(
                          avatarUrl: me?.avatarUrl,
                          name: me?.fullName ?? '',
                          size: 32,
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Viết bình luận...',
                        errorText: _inputError,
                        filled: true,
                        fillColor: AppColors.backgroundSecondary,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: state.sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : IconButton(
                            icon: const Icon(
                              AppIcons.send,
                              size: 28,
                              color: AppColors.primary600,
                            ),
                            onPressed: _send,
                          ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
