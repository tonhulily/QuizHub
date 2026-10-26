import 'package:flutter/material.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/component_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/models/exam_models.dart';
import '../../../data/models/question_models.dart';
import '../../question_bank/widgets/qbank_widgets.dart';

/// Màu nhãn của từng độ khó.
(Color, Color) difficultyColors(Difficulty d) => switch (d) {
  Difficulty.easy => (AppColors.successDark, AppColors.successLight),
  Difficulty.medium => (AppColors.warningDark, AppColors.warningLight),
  Difficulty.hard => (AppColors.errorDark, AppColors.errorLight),
  Difficulty.unclassified => (AppColors.textSecondary, AppColors.chip),
};

class DifficultyChip extends StatelessWidget {
  final Difficulty difficulty;
  final int? count;

  const DifficultyChip({super.key, required this.difficulty, this.count});

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = difficultyColors(difficulty);
    return QbankChip(
      label: count == null ? difficulty.label : '${difficulty.label}: $count',
      color: fg,
      background: bg,
    );
  }
}

/// Số câu theo từng độ khó (bỏ qua mức không có câu nào).
class DifficultyStats extends StatelessWidget {
  final ExamStatistic statistic;
  const DifficultyStats({super.key, required this.statistic});

  @override
  Widget build(BuildContext context) {
    final s = statistic;
    final counts = {
      Difficulty.easy: s.easy,
      Difficulty.medium: s.medium,
      Difficulty.hard: s.hard,
      Difficulty.unclassified: s.unclassified,
    };
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final e in counts.entries)
          if (e.value > 0) DifficultyChip(difficulty: e.key, count: e.value),
      ],
    );
  }
}

/// Lựa chọn khi xuất đề.
class ExportChoice {
  final ExportFormat format;
  final bool includeAnswerKey;
  final String paperSize;

  const ExportChoice({
    required this.format,
    required this.includeAnswerKey,
    required this.paperSize,
  });
}

/// Bottom sheet chọn định dạng / đáp án / khổ giấy. null nếu huỷ.
Future<ExportChoice?> showExportSheet(BuildContext context) =>
    showModalBottomSheet<ExportChoice>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      builder: (_) => const _ExportSheet(),
    );

class _ExportSheet extends StatefulWidget {
  const _ExportSheet();

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  static const _paperSizes = ['A4', 'A5', 'Letter'];

  ExportFormat _format = ExportFormat.pdf;
  bool _answerKey = false;
  String _paper = 'A4';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ComponentTokens.bottomSheetPadding,
          0,
          ComponentTokens.bottomSheetPadding,
          ComponentTokens.bottomSheetPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Xuất đề thi',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<ExportFormat>(
              showSelectedIcon: false,
              segments: [
                for (final f in ExportFormat.values)
                  ButtonSegment(value: f, label: Text(f.label)),
              ],
              selected: {_format},
              onSelectionChanged: (v) => setState(() => _format = v.first),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Kèm bảng đáp án'),
              value: _answerKey,
              onChanged: (v) => setState(() => _answerKey = v),
            ),
            if (_format == ExportFormat.pdf) ...[
              Text(
                'Khổ giấy',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in _paperSizes)
                    ChoiceChip(
                      label: Text(p),
                      selected: _paper == p,
                      onSelected: (_) => setState(() => _paper = p),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            AppButton(
              label: 'Xuất file',
              onPressed: () => Navigator.pop(
                context,
                ExportChoice(
                  format: _format,
                  includeAnswerKey: _answerKey,
                  paperSize: _paper,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Link tải chỉ dùng được trong thời gian ngắn, file sẽ mở ngay '
              'sau khi xuất.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
