import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/fb_widgets.dart';
import '../../../data/models/ai_models.dart';
import '../../../data/models/question_models.dart';
import '../../../data/repositories/ai_repository.dart';
import '../../../data/repositories/submission_repository.dart';
import '../../../di/locator.dart';
import '../../profile/cubit/profile_cubit.dart';
import '../cubit/ai_refine_cubit.dart';
import '../widgets/qbank_widgets.dart';

/// Nhờ AI tinh chỉnh một câu hỏi ([AiRefineArgs]). Lưu bản gợi ý xong
/// `pop(true)` để màn trước tải lại.
class AiRefineView extends StatelessWidget {
  final AiRefineArgs args;

  const AiRefineView({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    final role = context.read<ProfileCubit>().state.profile?.role;
    return BlocProvider(
      create: (_) => AiRefineCubit(
        getIt<AiRepository>(),
        getIt<SubmissionRepository>(),
        args: args,
        canApply: canApplyAi(role),
      ),
      child: const _Body(),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body();

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  static const _presets = [
    'Viết lại đề cho rõ ràng, ngắn gọn',
    'Làm các phương án nhiễu hợp lý hơn',
    'Viết lời giải chi tiết từng bước',
    'Sửa lỗi chính tả và thuật ngữ',
  ];

  final _prompt = TextEditingController();

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _refine() async {
    FocusScope.of(context).unfocus();
    final error = await context.read<AiRefineCubit>().refine(_prompt.text);
    if (error != null && mounted) AppFeedback.error(context, error);
  }

  Future<void> _accept() async {
    final cubit = context.read<AiRefineCubit>();
    // Giảng viên ghi đè câu trong ngân hàng: ảnh hưởng mọi người đang luyện
    // tập và các đề thi dùng câu này, nên hỏi lại
    if (cubit.canApply) {
      final ok = await showConfirmDialog(
        context,
        title: 'Áp dụng bản AI?',
        message:
            'Câu hỏi gốc trong ngân hàng sẽ bị ghi đè bằng bản gợi ý. Người '
            'luyện tập và các đề thi dùng câu này sẽ thấy nội dung mới.',
        confirmLabel: 'Áp dụng',
      );
      if (!ok || !mounted) return;
    }
    final error = await cubit.accept();
    if (!mounted) return;
    if (error != null) {
      AppFeedback.error(context, error);
      return;
    }
    AppFeedback.success(context, 'Đã cập nhật câu hỏi theo bản gợi ý.');
    Navigator.of(context).pop(true);
  }

  Future<void> _discard() async {
    final error = await context.read<AiRefineCubit>().discard();
    if (!mounted) return;
    if (error != null) AppFeedback.error(context, error);
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<AiRefineCubit>();
    final q = cubit.target;
    return BlocBuilder<AiRefineCubit, AiRefineState>(
      builder: (context, state) {
        final r = state.result;
        return Scaffold(
          backgroundColor: AppColors.backgroundSecondary,
          appBar: AppBar(title: Text('AI tinh chỉnh · ${q.label}')),
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                QbankBlock(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const QbankSectionTitle('Câu hiện tại'),
                      const SizedBox(height: 8),
                      _QuestionPreview(
                        content: q.content,
                        imageUrls: q.imageUrls,
                        options: q.options,
                        explanation: q.explanation,
                      ),
                    ],
                  ),
                ),
                const SectionGap(),
                QbankBlock(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const QbankSectionTitle('Yêu cầu cho AI'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in _presets)
                            ActionChip(
                              label: Text(p),
                              onPressed: state.busy
                                  ? null
                                  : () => setState(() => _prompt.text = p),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _prompt,
                        label: 'Bạn muốn AI sửa gì?',
                        maxLines: 3,
                        maxLength: AiRepository.maxPromptLength,
                        enabled: !state.busy,
                      ),
                      const SizedBox(height: 8),
                      AppButton(
                        label: r == null ? 'Gửi cho AI' : 'Gợi ý lại',
                        icon: AppIcons.bolt,
                        variant: r == null
                            ? AppButtonVariant.primary
                            : AppButtonVariant.outline,
                        loading: state.status == AiRefineStatus.refining,
                        onPressed: state.busy ? null : _refine,
                      ),
                      if (state.status == AiRefineStatus.refining) ...[
                        const SizedBox(height: 8),
                        Text(
                          'AI đang viết lại và tự kiểm tra ảo giác, có thể '
                          'mất vài giây...',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (r != null) ...[const SectionGap(), _ResultBlock(result: r)],
              ],
            ),
          ),
          bottomNavigationBar: !state.hasSuggestion
              ? null
              : SafeArea(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      border: Border(
                        top: BorderSide(color: AppColors.borderLight),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: cubit.canAccept
                        ? Row(
                            children: [
                              Expanded(
                                child: AppButton(
                                  label: 'Bỏ qua',
                                  variant: AppButtonVariant.outline,
                                  onPressed: state.busy ? null : _discard,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: AppButton(
                                  label: cubit.canApply
                                      ? 'Áp dụng'
                                      : 'Dùng bản gợi ý',
                                  loading:
                                      state.status == AiRefineStatus.saving,
                                  onPressed: state.busy ? null : _accept,
                                ),
                              ),
                            ],
                          )
                        // Không có quyền ghi: bản AI chỉ để tham khảo
                        : Text(
                            'Bản gợi ý chỉ để tham khảo: chỉ giảng viên '
                            'mới áp dụng được cho câu hỏi này.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                  ),
                ),
        );
      },
    );
  }
}

class _ResultBlock extends StatelessWidget {
  final AiRefineResult result;
  const _ResultBlock({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = result;
    final score = r.confidenceScore;
    final meta = [
      if (r.model != null) r.model!,
      if (r.tokensUsed != null) '${r.tokensUsed} token',
      if (r.processingMs != null)
        '${(r.processingMs! / 1000).toStringAsFixed(1)} giây',
    ].join(' · ');

    return QbankBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const QbankSectionTitle('Bản gợi ý của AI'),
          const SizedBox(height: 8),
          if (r.refused)
            ExplanationBox(
              title: 'AI từ chối yêu cầu',
              text: r.refusalReason!,
              icon: AppIcons.error,
              color: AppColors.errorDark,
              background: AppColors.errorLight,
            )
          else ...[
            if (r.isHallucinated)
              ExplanationBox(
                title: 'Cảnh báo: có dấu hiệu ảo giác',
                text:
                    'Kiểm tra kỹ trước khi dùng. '
                    '${score == null ? '' : 'Độ tin cậy ${(score * 100).round()}%.'}',
                icon: AppIcons.error,
                color: AppColors.warningDark,
                background: AppColors.warningLight,
              )
            else
              ExplanationBox(
                title: 'Không phát hiện ảo giác',
                text: score == null
                    ? ''
                    : 'Độ tin cậy ${(score * 100).round()}%.',
                icon: AppIcons.shieldCheck,
                color: AppColors.successDark,
                background: AppColors.successLight,
              ),
            for (final v in r.violations) ...[
              const SizedBox(height: 8),
              _ViolationTile(violation: v),
            ],
            const SizedBox(height: 12),
            _QuestionPreview(
              content: r.content,
              options: r.options,
              explanation: r.explanation,
            ),
          ],
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              meta,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ViolationTile extends StatelessWidget {
  final AiViolation violation;
  const _ViolationTile({required this.violation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = violation;
    final severe = v.severity == 'HIGH' || v.severity == 'CRITICAL';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(
          color: severe ? AppColors.error : AppColors.borderLight,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [v.type, ?v.severity].join(' · '),
            style: theme.textTheme.labelLarge?.copyWith(
              color: severe ? AppColors.errorDark : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (v.statement != null) ...[
            const SizedBox(height: 4),
            Text('"${v.statement}"', style: theme.textTheme.bodyMedium),
          ],
          if (v.detail != null) ...[
            const SizedBox(height: 4),
            Text(
              v.detail!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Nội dung + phương án (đáp án đúng tô xanh) + lời giải.
class _QuestionPreview extends StatelessWidget {
  final String content;
  final List<String> imageUrls;
  final List<QuestionOption> options;
  final String? explanation;

  const _QuestionPreview({
    required this.content,
    this.imageUrls = const [],
    required this.options,
    this.explanation,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      QuestionBody(content: content, imageUrls: imageUrls),
      const SizedBox(height: 12),
      for (final o in options) ...[
        OptionTile(
          option: o,
          look: o.isCorrect == true ? OptionLook.correct : OptionLook.idle,
        ),
        const SizedBox(height: 8),
      ],
      if (explanation != null && explanation!.trim().isNotEmpty)
        ExplanationBox(title: 'Lời giải', text: explanation!),
    ],
  );
}
