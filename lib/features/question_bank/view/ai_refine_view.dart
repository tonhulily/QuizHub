import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../core/utils/text_diff.dart';
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
                      _QuestionPreview(_Version.ofTarget(q)),
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
                if (r != null) ...[
                  const SectionGap(),
                  _ResultBlock(original: _Version.ofTarget(q), result: r),
                ],
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
  /// Câu hiện tại, để tô chỗ AI đã sửa.
  final _Version original;
  final AiRefineResult result;
  const _ResultBlock({required this.original, required this.result});

  void _compare(BuildContext context, _Version suggestion) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.92,
          child: _CompareSheet(before: original, after: suggestion),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = result;
    final suggestion = _Version.ofResult(r);
    final changed = original.differsFrom(suggestion);
    final correctChange = original.correctChange(suggestion);
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
          Row(
            children: [
              const Expanded(child: QbankSectionTitle('Bản gợi ý của AI')),
              if (!r.refused)
                TextButton.icon(
                  onPressed: () => _compare(context, suggestion),
                  icon: const Icon(AppIcons.compare, size: 18),
                  label: const Text('So sánh'),
                ),
            ],
          ),
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
            if (correctChange != null) ...[
              ExplanationBox(
                title: 'AI đổi đáp án đúng',
                text: correctChange,
                icon: AppIcons.errorOutline,
                color: AppColors.warningDark,
                background: AppColors.warningLight,
              ),
              const SizedBox(height: 8),
            ],
            _DiffLegend(changed: changed),
            const SizedBox(height: 8),
            _QuestionPreview.diff(
              version: suggestion,
              other: original,
              side: _Side.after,
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

/// Một bản của câu hỏi (gốc hoặc AI sửa) để hiển thị / so sánh.
class _Version {
  final String content;
  final List<String> imageUrls;
  final List<QuestionOption> options;
  final String explanation;

  const _Version({
    required this.content,
    this.imageUrls = const [],
    required this.options,
    this.explanation = '',
  });

  factory _Version.ofTarget(AiTarget t) => _Version(
    content: t.content,
    imageUrls: t.imageUrls,
    options: t.options,
    explanation: t.explanation ?? '',
  );

  factory _Version.ofResult(AiRefineResult r) => _Version(
    content: r.content,
    options: r.options,
    explanation: r.explanation ?? '',
  );

  String textOf(String key) {
    for (final o in options) {
      if (o.key == key) return o.text;
    }
    return '';
  }

  bool differsFrom(_Version o) =>
      content != o.content ||
      explanation != o.explanation ||
      options.length != o.options.length ||
      options.any((x) => x.text != o.textOf(x.key));

  /// "A → C" nếu đáp án đúng đổi. Câu luyện tập chưa làm bị ẩn đáp án thì
  /// không biết đáp án cũ: null.
  String? correctChange(_Version after) {
    if (options.every((o) => o.isCorrect == null)) return null;
    String keys(_Version v) => [
      for (final o in v.options)
        if (o.isCorrect == true) o.key,
    ].join(', ');
    final from = keys(this), to = keys(after);
    return from == to ? null : '${from.isEmpty ? '?' : from} → $to';
  }
}

/// Phía nào khi so sánh: bản gốc tô phần bị bỏ, bản AI tô phần thêm / sửa.
enum _Side { before, after }

/// Chữ của [side] với phần khác bản kia được tô màu.
InlineSpan _diffSpan(String before, String after, _Side side) {
  const added = TextStyle(
    backgroundColor: AppColors.successLight,
    color: AppColors.successDark,
    fontWeight: FontWeight.w600,
  );
  const removed = TextStyle(
    backgroundColor: AppColors.errorLight,
    color: AppColors.errorDark,
    decoration: TextDecoration.lineThrough,
  );
  return TextSpan(
    children: [
      for (final p in diffWords(before, after))
        if (p.op == DiffOp.same)
          TextSpan(text: p.text)
        else if (side == _Side.after && p.op == DiffOp.added)
          TextSpan(text: p.text, style: added)
        else if (side == _Side.before && p.op == DiffOp.removed)
          TextSpan(text: p.text, style: removed),
    ],
  );
}

/// Chú thích màu dưới tiêu đề bản gợi ý.
class _DiffLegend extends StatelessWidget {
  final bool changed;
  const _DiffLegend({required this.changed});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);
    if (!changed) {
      return Text('AI giữ nguyên nội dung câu hỏi.', style: style);
    }
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(
            text: ' Tô xanh ',
            style: TextStyle(
              backgroundColor: AppColors.successLight,
              color: AppColors.successDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          const TextSpan(
            text:
                ' là chỗ AI thêm / sửa so với câu hiện tại. Bấm "So sánh" '
                'để xem hai bản cạnh nhau.',
          ),
        ],
      ),
      style: style,
    );
  }
}

/// Bản gốc và bản AI đặt cạnh nhau.
class _CompareSheet extends StatelessWidget {
  final _Version before;
  final _Version after;

  const _CompareSheet({required this.before, required this.after});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget column(String title, _Version v, _Version other, _Side side) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: side == _Side.before
                        ? AppColors.errorDark
                        : AppColors.successDark,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: _QuestionPreview.diff(
                    version: v,
                    other: other,
                    side: side,
                    showImages: false,
                  ),
                ),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            'So sánh bản gốc và bản AI',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              column('Bản gốc', before, after, _Side.before),
              const VerticalDivider(width: 1),
              column('Bản AI', after, before, _Side.after),
            ],
          ),
        ),
      ],
    );
  }
}

/// Nội dung + phương án (đáp án đúng tô xanh) + lời giải.
class _QuestionPreview extends StatelessWidget {
  final _Version version;

  /// Bản để so sánh; null thì hiện bình thường, không tô.
  final _Version? other;
  final _Side side;
  final bool showImages;

  const _QuestionPreview(this.version)
    : other = null,
      side = _Side.after,
      showImages = true;

  const _QuestionPreview.diff({
    required this.version,
    required _Version this.other,
    required this.side,
    this.showImages = true,
  });

  /// Chữ của bản này, tô phần khác [other].
  InlineSpan? _span(String mine, String theirs) {
    if (other == null) return null;
    return side == _Side.before
        ? _diffSpan(mine, theirs, side)
        : _diffSpan(theirs, mine, side);
  }

  @override
  Widget build(BuildContext context) {
    final v = version;
    final o = other;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuestionBody(
          content: v.content,
          imageUrls: showImages ? v.imageUrls : const [],
          contentSpan: o == null ? null : _span(v.content, o.content),
        ),
        const SizedBox(height: 12),
        for (final opt in v.options) ...[
          OptionTile(
            option: opt,
            look: opt.isCorrect == true ? OptionLook.correct : OptionLook.idle,
            textSpan: o == null ? null : _span(opt.text, o.textOf(opt.key)),
          ),
          const SizedBox(height: 8),
        ],
        if (v.explanation.trim().isNotEmpty)
          ExplanationBox(
            title: 'Lời giải',
            text: v.explanation,
            textSpan: o == null ? null : _span(v.explanation, o.explanation),
          ),
      ],
    );
  }
}
