import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/fb_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/auth_session.dart';
import '../../../data/models/question_models.dart';
import '../../../data/repositories/question_bank_repository.dart';
import '../../../di/locator.dart';
import '../../profile/cubit/profile_cubit.dart';
import '../cubit/ai_refine_cubit.dart';
import '../cubit/load_cubit.dart';
import '../cubit/practice_cubit.dart';
import '../widgets/qbank_widgets.dart';
import '../widgets/rating_sheet.dart';

/// Luyện tập một phiên: từng câu một, nộp xong thấy ngay đúng / sai và lời
/// giải, sau đó có thể đánh giá câu hỏi và xem thống kê.
class PracticeView extends StatelessWidget {
  final int sessionId;
  const PracticeView({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        PracticeCubit(getIt<QuestionBankRepository>(), sessionId)..load(),
    child: const _PracticeBody(),
  );
}

class _PracticeBody extends StatelessWidget {
  const _PracticeBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PracticeCubit, PracticeState>(
      builder: (context, state) {
        final s = state.session;
        return Scaffold(
          backgroundColor: AppColors.backgroundSecondary,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s?.title ?? 'Luyện tập',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (s != null)
                  Text(
                    [
                      s.subjectCode ?? s.subjectName,
                      'Đã làm ${state.answeredCount}/${state.questions.length}',
                    ].whereType<String>().join(' · '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          body: switch (state.status) {
            LoadStatus.loading => const LoadingView(),
            LoadStatus.failure => ErrorView(
              error: state.error,
              onRetry: context.read<PracticeCubit>().load,
            ),
            LoadStatus.loaded when state.questions.isEmpty => const EmptyView(
              icon: AppIcons.quizActive,
              title: 'Phiên chưa có câu hỏi',
              message: 'Các câu được duyệt sẽ hiện ở đây.',
            ),
            LoadStatus.loaded => Column(
              children: [
                _ProgressStrip(state: state),
                Expanded(child: _QuestionPage(state: state)),
              ],
            ),
          },
          bottomNavigationBar: state.current == null
              ? null
              : _ActionBar(state: state),
        );
      },
    );
  }
}

/// Dãy số câu: xanh = đúng, đỏ = sai, xám đậm = đã làm từ trước.
class _ProgressStrip extends StatelessWidget {
  final PracticeState state;
  const _ProgressStrip({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = state.questions.length;
    return Container(
      color: AppColors.white,
      child: Column(
        children: [
          LinearProgressIndicator(
            value: total == 0 ? 0 : state.answeredCount / total,
            minHeight: 3,
            color: AppColors.primary600,
            backgroundColor: AppColors.borderLight,
          ),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: total,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final q = state.questions[i];
                final r = state.results[q.questionId];
                final current = i == state.index;
                final (fg, bg) = switch ((q.answered, r?.isCorrect)) {
                  (_, true) => (AppColors.white, AppColors.success),
                  (_, false) => (AppColors.white, AppColors.error),
                  (true, null) => (AppColors.white, AppColors.neutral500),
                  _ => (AppColors.textPrimary, AppColors.chip),
                };
                return InkWell(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
                  onTap: () => context.read<PracticeCubit>().goTo(i),
                  child: Container(
                    width: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bg,
                      shape: BoxShape.circle,
                      border: current
                          ? Border.all(color: AppColors.primary600, width: 2.5)
                          : null,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class _QuestionPage extends StatelessWidget {
  final PracticeState state;
  const _QuestionPage({required this.state});

  Future<void> _aiRefine(BuildContext context, PracticeQuestion q) async {
    final cubit = context.read<PracticeCubit>();
    final changed = await Navigator.of(context).pushNamed(
      AppRoutes.qbankAiRefine,
      arguments: AiRefineArgs(AiTarget.fromPractice(q, state.index)),
    );
    if (changed == true) await cubit.load(silent: true);
  }

  OptionLook _look(PracticeQuestion q, String key, List<String> correct) {
    final mine = state.selected[q.questionId];
    if (!q.answered) {
      return mine == key ? OptionLook.selected : OptionLook.idle;
    }
    if (correct.contains(key)) return OptionLook.correct;
    if (mine == key) return OptionLook.wrong;
    return OptionLook.dimmed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = state.current!;
    final cubit = context.read<PracticeCubit>();
    final correct = state.correctKeysOf(q);
    final result = state.results[q.questionId];

    return ListView(
      key: ValueKey(q.questionId),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        QbankBlock(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Câu ${state.index + 1}/${state.questions.length}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.primary600,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (q.questionCode != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        q.questionCode!,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  SourceChip(source: q.source),
                  // Giảng viên sửa câu ngay khi xem (ghi đè câu trong ngân hàng)
                  if (canApplyAi(
                    context.select<ProfileCubit, UserRole?>(
                      (c) => c.state.profile?.role,
                    ),
                  ))
                    TextButton.icon(
                      onPressed: () => _aiRefine(context, q),
                      icon: const Icon(AppIcons.bolt, size: 16),
                      label: const Text('AI gợi ý'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              QuestionBody(content: q.content, imageUrls: q.imageUrls),
              const SizedBox(height: 16),
              for (final o in q.options) ...[
                OptionTile(
                  option: o,
                  look: _look(q, o.key, correct),
                  onTap: q.answered ? null : () => cubit.select(o.key),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        if (q.answered) ...[
          const SectionGap(),
          QbankBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (result != null)
                  ExplanationBox(
                    title: result.isCorrect
                        ? 'Chính xác!'
                        : 'Chưa đúng. Đáp án đúng: ${correct.join(', ')}',
                    text: '',
                    icon: result.isCorrect ? AppIcons.success : AppIcons.error,
                    color: result.isCorrect
                        ? AppColors.successDark
                        : AppColors.errorDark,
                    background: result.isCorrect
                        ? AppColors.successLight
                        : AppColors.errorLight,
                  )
                else
                  ExplanationBox(
                    title: correct.isEmpty
                        ? 'Bạn đã làm câu này'
                        : 'Bạn đã làm câu này. Đáp án đúng: ${correct.join(', ')}',
                    text: '',
                    icon: AppIcons.success,
                    color: AppColors.textSecondary,
                    background: AppColors.chip,
                  ),
                if (q.explanation != null &&
                    q.explanation!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ExplanationBox(title: 'Lời giải', text: q.explanation!),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  final PracticeState state;
  const _ActionBar({required this.state});

  Future<void> _submit(BuildContext context) async {
    final error = await context.read<PracticeCubit>().submit();
    if (error != null && context.mounted) AppFeedback.error(context, error);
  }

  Future<void> _rate(BuildContext context) async {
    final cubit = context.read<PracticeCubit>();
    final input = await showRatingSheet(context);
    if (input == null || !context.mounted) return;
    final error = await AppFeedback.withLoading(
      () => cubit.rate(
        rating: input.rating,
        isError: input.isError,
        comment: input.comment,
      ),
    );
    if (!context.mounted) return;
    if (error != null) {
      AppFeedback.error(context, error);
    } else {
      AppFeedback.success(
        context,
        input.isError ? 'Đã gửi báo lỗi.' : 'Cảm ơn bạn đã đánh giá!',
      );
    }
  }

  void _stats(BuildContext context, PracticeQuestion q) =>
      Navigator.of(context).pushNamed(
        AppRoutes.qbankQuestionStats,
        arguments: (
          questionId: q.questionId,
          correctKeys: state.correctKeysOf(q),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final q = state.current!;
    final cubit = context.read<PracticeCubit>();
    final isLast = state.index >= state.questions.length - 1;

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.borderLight)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: q.answered
            ? Row(
                children: [
                  HeaderIconButton(
                    icon: AppIcons.back,
                    iconSize: 22,
                    tooltip: 'Câu trước',
                    onTap: state.index == 0
                        ? null
                        : () => cubit.goTo(state.index - 1),
                  ),
                  Expanded(
                    child: AppButton(
                      label: q.rated ? 'Đã đánh giá' : 'Đánh giá',
                      icon: AppIcons.points,
                      small: true,
                      variant: AppButtonVariant.outline,
                      onPressed: q.rated ? null : () => _rate(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppButton(
                      label: 'Thống kê',
                      icon: AppIcons.leaderboard,
                      small: true,
                      variant: AppButtonVariant.outline,
                      onPressed: () => _stats(context, q),
                    ),
                  ),
                  HeaderIconButton(
                    icon: AppIcons.chevronRight,
                    iconSize: 22,
                    tooltip: 'Câu tiếp',
                    onTap: isLast ? null : () => cubit.goTo(state.index + 1),
                  ),
                ],
              )
            : AppButton(
                label: 'Nộp đáp án',
                loading: state.submitting,
                onPressed: state.selected[q.questionId] == null
                    ? null
                    : () => _submit(context),
              ),
      ),
    );
  }
}
