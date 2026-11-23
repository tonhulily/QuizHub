import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../data/models/game_models.dart';
import '../../question_bank/widgets/qbank_widgets.dart';

/// Gửi một lượt dự đoán: hiện loading, báo thành công / lỗi của server
/// (409 đã cược, quá 22:00...). Trả về lượt dự đoán khi thành công.
Future<GamePrediction?> submitPrediction(
  BuildContext context,
  Future<GamePrediction> Function() task, {
  String success = 'Đã ghi nhận dự đoán. Chúc bạn may mắn!',
}) async {
  try {
    final p = await AppFeedback.withLoading(task);
    if (context.mounted) AppFeedback.success(context, success);
    return p;
  } on ApiException catch (e) {
    if (context.mounted) AppFeedback.error(context, e);
    return null;
  }
}

/// Một ô nhập số nguyên trong hộp thoại dự đoán.
class PredictionField {
  final String label;
  final String? helper;
  final int min;
  final int? max;

  const PredictionField({
    required this.label,
    this.helper,
    this.min = 0,
    this.max,
  });
}

/// Hộp thoại nhập một hay nhiều số dự đoán. Trả về các số theo thứ tự
/// [fields], null nếu huỷ.
Future<List<int>?> showPredictionDialog(
  BuildContext context, {
  required String title,
  String? message,
  required List<PredictionField> fields,
  String confirmLabel = 'Chốt dự đoán',
}) => showDialog<List<int>>(
  context: context,
  builder: (_) => _PredictionDialog(
    title: title,
    message: message,
    fields: fields,
    confirmLabel: confirmLabel,
  ),
);

class _PredictionDialog extends StatefulWidget {
  final String title;
  final String? message;
  final List<PredictionField> fields;
  final String confirmLabel;

  const _PredictionDialog({
    required this.title,
    required this.message,
    required this.fields,
    required this.confirmLabel,
  });

  @override
  State<_PredictionDialog> createState() => _PredictionDialogState();
}

class _PredictionDialogState extends State<_PredictionDialog> {
  final _form = GlobalKey<FormState>();
  late final _controllers = [
    for (final _ in widget.fields) TextEditingController(),
  ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate(PredictionField f, String? raw) {
    final v = int.tryParse((raw ?? '').trim());
    if (v == null) return 'Nhập một số nguyên';
    if (v < f.min) return 'Tối thiểu ${f.min}';
    if (f.max != null && v > f.max!) return 'Tối đa ${f.max}';
    return null;
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.of(
      context,
    ).pop([for (final c in _controllers) int.parse(c.text.trim())]);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.message != null) ...[
                Text(widget.message!),
                const SizedBox(height: 12),
              ],
              for (var i = 0; i < widget.fields.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextFormField(
                    controller: _controllers[i],
                    autofocus: i == 0,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: i == widget.fields.length - 1
                        ? TextInputAction.done
                        : TextInputAction.next,
                    onFieldSubmitted: i == widget.fields.length - 1
                        ? (_) => _submit()
                        : null,
                    decoration: InputDecoration(
                      labelText: widget.fields[i].label,
                      helperText: widget.fields[i].helper,
                      helperMaxLines: 2,
                    ),
                    validator: (v) => _validate(widget.fields[i], v),
                  ),
                ),
              const Text(
                'Mỗi lượt chỉ được chốt một lần, không sửa lại được.',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: const Text('Huỷ'),
        ),
        TextButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// Thẻ giới thiệu một minigame trên màn "Minigame".
class GameCard extends StatelessWidget {
  final int number;
  final String title;
  final String description;
  final String reward;
  final IconData icon;
  final Color color;
  final String actionLabel;
  final VoidCallback onTap;

  const GameCard({
    super.key,
    required this.number,
    required this.title,
    required this.description,
    required this.reward,
    required this.icon,
    required this.color,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return QbankBlock(
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MINIGAME $number',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(description, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: QbankChip(
                          label: reward,
                          icon: AppIcons.trophy,
                          color: AppColors.warningDark,
                          background: AppColors.warningLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        actionLabel,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.primary600,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Icon(
                        AppIcons.chevronRight,
                        size: 14,
                        color: AppColors.primary600,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nhãn kết quả của một lượt dự đoán.
class PredictionResultChip extends StatelessWidget {
  final GamePrediction prediction;
  const PredictionResultChip({super.key, required this.prediction});

  @override
  Widget build(BuildContext context) {
    final p = prediction;
    if (!p.resolved) {
      return const QbankChip(
        label: 'Chờ kết quả',
        icon: AppIcons.joined,
        color: AppColors.infoDark,
        background: AppColors.infoLight,
      );
    }
    return p.isCorrect
        ? const QbankChip(
            label: 'Đoán trúng',
            icon: AppIcons.success,
            color: AppColors.successDark,
            background: AppColors.successLight,
          )
        : const QbankChip(
            label: 'Chưa trúng',
            icon: AppIcons.error,
            color: AppColors.errorDark,
            background: AppColors.errorLight,
          );
  }
}

/// Một dòng trong lịch sử dự đoán.
class PredictionTile extends StatelessWidget {
  final GamePrediction prediction;

  /// Tên đối tượng đã cược (lớp / môn / phiên) nếu biết.
  final String? targetLabel;

  const PredictionTile({super.key, required this.prediction, this.targetLabel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = prediction;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
    );
    final actual = p.actualText;
    return QbankBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.gameType.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PredictionResultChip(prediction: p),
            ],
          ),
          if (targetLabel != null) ...[
            const SizedBox(height: 4),
            Text(targetLabel!, style: muted),
          ],
          const SizedBox(height: 8),
          Text('Bạn đoán: ${p.predictionText}'),
          if (actual != null) ...[
            const SizedBox(height: 2),
            Text('Thực tế: $actual'),
          ],
          const SizedBox(height: 6),
          Text(
            [
              if (p.createdAt != null) 'Đặt ${TimeFormat.ago(p.createdAt)}',
              if (p.resolvedAt != null)
                'Tổng kết ${TimeFormat.dateTime(p.resolvedAt)}',
            ].join(' · '),
            style: muted,
          ),
        ],
      ),
    );
  }
}
