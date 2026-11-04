import 'package:flutter/material.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/design_system/component_tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/models/question_models.dart';

/// Đánh giá người dùng chọn trong [showRatingSheet].
class RatingInput {
  final int rating;
  final bool isError;
  final String? comment;

  const RatingInput({required this.rating, this.isError = false, this.comment});
}

/// Bottom sheet chấm câu hỏi theo thang 0-4 của backend, kèm báo lỗi.
/// Trả về null nếu người dùng đóng sheet.
Future<RatingInput?> showRatingSheet(BuildContext context) =>
    showModalBottomSheet<RatingInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.white,
      builder: (_) => const _RatingSheet(),
    );

class _RatingSheet extends StatefulWidget {
  const _RatingSheet();

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  final _comment = TextEditingController();
  RatingLevel? _level;
  bool _isError = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _isError ? _comment.text.trim().isNotEmpty : _level != null;

  void _submit() {
    if (!_canSubmit) return;
    final note = _comment.text.trim();
    Navigator.pop(
      context,
      RatingInput(
        rating: _isError ? 0 : _level!.value,
        isError: _isError,
        comment: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ComponentTokens.bottomSheetPadding,
        0,
        ComponentTokens.bottomSheetPadding,
        ComponentTokens.bottomSheetPadding +
            MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Đánh giá câu hỏi',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Mỗi câu chỉ đánh giá được một lần.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            // Mức cao lên trước: người dùng hay chọn "hay" / "cơ bản" nhất
            for (final level in RatingLevel.values.reversed)
              _LevelRow(
                level: level,
                selected: !_isError && _level == level,
                enabled: !_isError,
                onTap: () => setState(() => _level = level),
              ),
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isError,
              activeThumbColor: AppColors.error,
              onChanged: (v) => setState(() => _isError = v),
              title: const Text('Báo lỗi câu hỏi'),
              subtitle: const Text(
                'Đề hoặc đáp án sai. Điểm đánh giá sẽ tính là 0 và giảng viên '
                'sẽ thẩm định.',
              ),
            ),
            const SizedBox(height: 8),
            AppTextField(
              controller: _comment,
              label: _isError ? 'Mô tả lỗi (bắt buộc)' : 'Nhận xét (tuỳ chọn)',
              maxLines: 3,
              maxLength: 500,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: _isError ? 'Gửi báo lỗi' : 'Gửi đánh giá',
              variant: _isError
                  ? AppButtonVariant.danger
                  : AppButtonVariant.primary,
              onPressed: _canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  final RatingLevel level;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _LevelRow({
    required this.level,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = enabled ? AppColors.textPrimary : AppColors.textDisabled;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              selected ? AppIcons.radioOn : AppIcons.radioOff,
              color: selected ? AppColors.primary600 : AppColors.textTertiary,
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 22,
              child: Text(
                '${level.value}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                level.label,
                style: theme.textTheme.bodyLarge?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
