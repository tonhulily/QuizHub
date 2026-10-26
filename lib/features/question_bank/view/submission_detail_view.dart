import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/fb_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/question_models.dart';
import '../../../data/models/session_models.dart';
import '../../../data/repositories/submission_repository.dart';
import '../../../di/locator.dart';
import '../../../shared/widgets/link_text.dart';
import '../cubit/ai_refine_cubit.dart';
import '../cubit/load_cubit.dart';
import '../widgets/qbank_widgets.dart';

/// Chi tiết một phiên CỦA TÔI: mọi câu kèm đáp án đúng, độ tự tin, người
/// duyệt. Sửa / xoá chỉ khi phiên còn chờ duyệt.
class SubmissionDetailView extends StatelessWidget {
  final int sessionId;

  /// Trạng thái biết được từ danh sách (tab đang lọc). Chi tiết theo Swagger
  /// không có `status`; có thì ưu tiên dữ liệu của chi tiết.
  final SessionStatus statusHint;

  const SubmissionDetailView({
    super.key,
    required this.sessionId,
    this.statusHint = SessionStatus.unknown,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => LoadCubit<SubmissionDetail>(
      () => getIt<SubmissionRepository>().detail(sessionId),
    )..load(),
    child: _DetailBody(statusHint: statusHint),
  );
}

class _DetailBody extends StatelessWidget {
  final SessionStatus statusHint;
  const _DetailBody({required this.statusHint});

  SessionStatus _status(SubmissionDetail d) =>
      d.status != SessionStatus.unknown ? d.status : statusHint;

  Future<void> _aiRefine(
    BuildContext context,
    SubmissionDetail d,
    int index,
  ) async {
    final cubit = context.read<LoadCubit<SubmissionDetail>>();
    final changed = await Navigator.of(context).pushNamed(
      AppRoutes.qbankAiRefine,
      arguments: AiRefineArgs.fromSession(d, index),
    );
    if (changed == true) cubit.load(silent: true);
  }

  Future<void> _edit(BuildContext context, SubmissionDetail d) async {
    final cubit = context.read<LoadCubit<SubmissionDetail>>();
    final saved = await Navigator.of(
      context,
    ).pushNamed(AppRoutes.qbankSubmissionForm, arguments: d);
    if (saved != true || !context.mounted) return;
    AppFeedback.success(context, 'Đã lưu thay đổi.');
    cubit.load(silent: true);
  }

  Future<void> _delete(BuildContext context, SubmissionDetail d) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Xoá phiên đề xuất?',
      message:
          'Toàn bộ ${d.questions.length} câu hỏi và ảnh của phiên '
          '"${d.title}" sẽ bị xoá. Không thể hoàn tác.',
      confirmLabel: 'Xoá',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await AppFeedback.withLoading(
        () => getIt<SubmissionRepository>().delete(d.sessionId),
      );
      if (!context.mounted) return;
      AppFeedback.success(context, 'Đã xoá phiên.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (context.mounted) AppFeedback.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<
      LoadCubit<SubmissionDetail>,
      LoadState<SubmissionDetail>
    >(
      builder: (context, state) {
        final d = state.data;
        final editable = d != null && _status(d).editable;
        return Scaffold(
          backgroundColor: AppColors.backgroundSecondary,
          appBar: AppBar(
            title: const Text('Chi tiết phiên'),
            actions: [
              if (editable) ...[
                IconButton(
                  tooltip: 'Sửa phiên',
                  icon: const Icon(AppIcons.edit),
                  onPressed: () => _edit(context, d),
                ),
                IconButton(
                  tooltip: 'Xoá phiên',
                  icon: const Icon(AppIcons.delete),
                  onPressed: () => _delete(context, d),
                ),
              ],
            ],
          ),
          body: switch (state.status) {
            LoadStatus.loading => const LoadingView(),
            LoadStatus.failure => ErrorView(
              error: state.error,
              onRetry: context.read<LoadCubit<SubmissionDetail>>().load,
            ),
            LoadStatus.loaded => RefreshIndicator(
              onRefresh: () => context.read<LoadCubit<SubmissionDetail>>().load(
                silent: true,
              ),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  _InfoBlock(detail: d!, status: _status(d)),
                  for (var i = 0; i < d.questions.length; i++) ...[
                    const SectionGap(),
                    _QuestionBlock(
                      index: i,
                      question: d.questions[i],
                      onAiRefine: editable
                          ? () => _aiRefine(context, d, i)
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          },
          bottomNavigationBar: d == null || d.questions.isEmpty
              ? null
              : SafeArea(
                  child: Container(
                    color: AppColors.white,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: AppButton(
                      label: 'Làm thử phiên này',
                      icon: AppIcons.play,
                      onPressed: () => Navigator.of(context).pushNamed(
                        AppRoutes.qbankPractice,
                        arguments: d.sessionId,
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final SubmissionDetail detail;
  final SessionStatus status;

  const _InfoBlock({required this.detail, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = detail;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
    );
    return QbankBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if ((d.subjectCode ?? d.subjectName) != null)
                QbankChip(
                  label: [
                    d.subjectCode,
                    d.subjectName,
                  ].whereType<String>().join(' · '),
                  icon: AppIcons.subject,
                  color: AppColors.primary700,
                  background: AppColors.primary50,
                ),
              SessionStatusChip(status: status),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            d.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (d.content != null && d.content!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(d.content!, style: theme.textTheme.bodyMedium),
          ],
          if (d.sourceUrl != null) ...[
            const SizedBox(height: 6),
            LinkText('Nguồn: ${d.sourceUrl}', style: muted),
          ],
          const SizedBox(height: 10),
          Text(
            [
              if (d.sessionCode != null) d.sessionCode!,
              '${d.questions.length} câu hỏi',
              if (d.createdAt != null) 'Gửi ${TimeFormat.ago(d.createdAt)}',
            ].join(' · '),
            style: muted,
          ),
          if (d.reviewedBy != null) ...[
            const SizedBox(height: 4),
            Text(
              'Duyệt bởi ${d.reviewedBy}'
              '${d.reviewedAt == null ? '' : ' · ${TimeFormat.dateTime(d.reviewedAt)}'}',
              style: muted,
            ),
          ],
          if (status == SessionStatus.unknown) ...[
            const SizedBox(height: 12),
            const ExplanationBox(
              title: 'Chưa rõ trạng thái phiên',
              text:
                  'Mở phiên từ tab "Chờ duyệt" để sửa hoặc xoá (chỉ phiên '
                  'đang chờ duyệt mới sửa được).',
            ),
          ],
        ],
      ),
    );
  }
}

class _QuestionBlock extends StatelessWidget {
  final int index;
  final SubmissionQuestion question;

  /// null = không cho nhờ AI (phiên đã duyệt / chưa rõ trạng thái).
  final VoidCallback? onAiRefine;

  const _QuestionBlock({
    required this.index,
    required this.question,
    this.onAiRefine,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = question;
    final level = RatingLevel.fromValue(q.confidence);
    return QbankBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Câu ${index + 1}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.primary600,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              SourceChip(source: q.source),
              const Spacer(),
              QuestionStatusChip(status: q.status),
              if (onAiRefine != null)
                TextButton.icon(
                  onPressed: onAiRefine,
                  icon: const Icon(AppIcons.bolt, size: 16),
                  label: const Text('AI gợi ý'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          QuestionBody(content: q.content, imageUrls: q.imageUrls),
          const SizedBox(height: 12),
          for (final o in q.options) ...[
            OptionTile(
              option: o,
              look: o.isCorrect == true ? OptionLook.correct : OptionLook.idle,
            ),
            const SizedBox(height: 8),
          ],
          if (q.explanation != null && q.explanation!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            ExplanationBox(title: 'Lời giải', text: q.explanation!),
          ],
          const SizedBox(height: 10),
          Text(
            [
              if (level != null) 'Độ tự tin: ${level.value} - ${level.label}',
              '${q.ratingCount} đánh giá',
              '${q.commentCount} bình luận',
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
