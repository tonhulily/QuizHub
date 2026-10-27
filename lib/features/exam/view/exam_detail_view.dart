import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/fb_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/auth_session.dart';
import '../../../data/models/exam_models.dart';
import '../../../data/repositories/exam_repository.dart';
import '../../../di/locator.dart';
import '../../profile/cubit/profile_cubit.dart';
import '../../question_bank/cubit/ai_refine_cubit.dart';
import '../../question_bank/cubit/load_cubit.dart';
import '../../question_bank/widgets/qbank_widgets.dart';
import '../widgets/exam_widgets.dart';

/// Chi tiết / xem trước đề thi: câu hỏi theo thứ tự, độ khó, chủ đề, đáp án;
/// xuất PDF hoặc Excel.
class ExamDetailView extends StatelessWidget {
  final int examId;

  /// Đề vừa sinh: hiện ngay, không cần gọi lại API (màn "Xem trước").
  final ExamDetail? initial;

  const ExamDetailView({super.key, required this.examId, this.initial});

  @override
  Widget build(BuildContext context) {
    final repo = getIt<ExamRepository>();
    return BlocProvider(
      create: (_) {
        final cubit = LoadCubit<ExamDetail>(
          () => repo.detail(examId),
          initial: initial,
        );
        if (initial == null) cubit.load();
        return cubit;
      },
      child: _Body(isPreview: initial != null),
    );
  }
}

class _Body extends StatefulWidget {
  final bool isPreview;
  const _Body({required this.isPreview});

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  bool _showAnswers = false;

  /// Sửa câu ngay trong đề: bản AI ghi đè câu gốc trong ngân hàng, rồi tải
  /// lại đề để thấy nội dung mới.
  Future<void> _aiRefine(ExamQuestion q) async {
    final cubit = context.read<LoadCubit<ExamDetail>>();
    final changed = await Navigator.of(context).pushNamed(
      AppRoutes.qbankAiRefine,
      arguments: AiRefineArgs(AiTarget.fromExam(q)),
    );
    if (changed == true) await cubit.load(silent: true);
  }

  Future<void> _export(ExamDetail exam) async {
    final choice = await showExportSheet(context);
    if (choice == null || !mounted) return;
    try {
      final r = await AppFeedback.withLoading(
        () => getIt<ExamRepository>().exportFile(
          exam.examId,
          format: choice.format,
          includeAnswerKey: choice.includeAnswerKey,
          paperSize: choice.paperSize,
        ),
      );
      final uri = Uri.tryParse(r.downloadUrl);
      if (uri == null || r.downloadUrl.isEmpty) {
        throw const ApiException(
          type: ApiErrorType.server,
          message: 'Máy chủ không trả về link tải file.',
        );
      }
      // Link có hạn: mở ngay bằng trình duyệt / ứng dụng xem file. Máy không
      // có ứng dụng mở được link thì launchUrl ném PlatformException
      // (vd ACTIVITY_NOT_FOUND trên Android) thay vì trả false.
      bool opened;
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } on PlatformException {
        opened = false;
      }
      if (!mounted) return;
      if (!opened) {
        AppFeedback.errorMessage(context, 'Không mở được file vừa xuất.');
      }
    } on ApiException catch (e) {
      if (mounted) AppFeedback.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoadCubit<ExamDetail>, LoadState<ExamDetail>>(
      builder: (context, state) {
        final exam = state.data;
        final canAi = canApplyAi(
          context.select<ProfileCubit, UserRole?>((c) => c.state.profile?.role),
        );
        return Scaffold(
          backgroundColor: AppColors.backgroundSecondary,
          appBar: AppBar(
            title: Text(widget.isPreview ? 'Xem trước đề' : 'Chi tiết đề thi'),
            actions: [
              if (exam != null)
                IconButton(
                  tooltip: _showAnswers ? 'Ẩn đáp án' : 'Hiện đáp án',
                  icon: Icon(_showAnswers ? AppIcons.eyeOff : AppIcons.eye),
                  onPressed: () => setState(() => _showAnswers = !_showAnswers),
                ),
            ],
          ),
          body: switch (state.status) {
            LoadStatus.loading => const LoadingView(),
            LoadStatus.failure => ErrorView(
              error: state.error,
              onRetry: context.read<LoadCubit<ExamDetail>>().load,
            ),
            LoadStatus.loaded => ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _Header(exam: exam!, isPreview: widget.isPreview),
                for (final q in exam.questions) ...[
                  const SectionGap(),
                  _QuestionBlock(
                    question: q,
                    showAnswer: _showAnswers,
                    onAiRefine: canAi ? () => _aiRefine(q) : null,
                  ),
                ],
                if (exam.questions.isEmpty)
                  const SizedBox(
                    height: 260,
                    child: EmptyView(
                      icon: AppIcons.exam,
                      title: 'Đề không có câu hỏi',
                      message: 'Ngân hàng của môn này chưa đủ câu đã duyệt.',
                    ),
                  ),
              ],
            ),
          },
          bottomNavigationBar: exam == null
              ? null
              : SafeArea(
                  child: Container(
                    color: AppColors.white,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: AppButton(
                      label: 'Xuất PDF / Excel',
                      icon: AppIcons.exam,
                      onPressed: () => _export(exam),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final ExamDetail exam;
  final bool isPreview;

  const _Header({required this.exam, required this.isPreview});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return QbankBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPreview) ...[
            const ExplanationBox(
              title: 'Đã sinh đề thành công',
              text:
                  'Đề đã được lưu vào "Đề thi của tôi" và gán cho các lớp '
                  'đã chọn.',
              icon: AppIcons.success,
              color: AppColors.successDark,
              background: AppColors.successLight,
            ),
            const SizedBox(height: 12),
          ],
          if (exam.subjectName != null)
            QbankChip(
              label: exam.subjectName!,
              icon: AppIcons.subject,
              color: AppColors.primary700,
              background: AppColors.primary50,
            ),
          const SizedBox(height: 8),
          Text(
            exam.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            [
              '${exam.questionCount} câu hỏi',
              if (exam.createdAt != null) TimeFormat.dateTime(exam.createdAt),
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          DifficultyStats(statistic: exam.statistic),
        ],
      ),
    );
  }
}

class _QuestionBlock extends StatelessWidget {
  final ExamQuestion question;
  final bool showAnswer;

  /// null = không có quyền nhờ AI sửa câu.
  final VoidCallback? onAiRefine;

  const _QuestionBlock({
    required this.question,
    required this.showAnswer,
    this.onAiRefine,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = question;
    return QbankBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Câu ${q.order}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.primary600,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              DifficultyChip(difficulty: q.difficulty),
              if (q.topic != null) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    q.topic!,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
              const Spacer(),
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
              look: showAnswer && o.isCorrect == true
                  ? OptionLook.correct
                  : OptionLook.idle,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
