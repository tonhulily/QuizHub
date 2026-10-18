import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_feedback.dart';
import '../../data/repositories/report_repository.dart';
import '../../di/locator.dart';

/// Bottom sheet báo cáo vi phạm (bài viết / bình luận / người dùng).
Future<void> showReportSheet(
  BuildContext context, {
  required ReportTarget target,
  required int targetId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ReportSheet(target: target, targetId: targetId),
  );
}

class _ReportSheet extends StatefulWidget {
  final ReportTarget target;
  final int targetId;

  const _ReportSheet({required this.target, required this.targetId});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ViolationType _type = ViolationType.spam;
  final _descCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await getIt<ReportRepository>().report(
        targetType: widget.target,
        targetId: widget.targetId,
        violation: _type,
        description: _descCtrl.text,
      );
      if (!mounted) return;
      final nav = Navigator.of(context);
      AppFeedback.success(context, 'Đã gửi báo cáo. Cảm ơn bạn đã góp ý!');
      nav.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppFeedback.error(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Báo cáo nội dung', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Hãy cho chúng tôi biết vấn đề của nội dung này.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            RadioGroup<ViolationType>(
              groupValue: _type,
              onChanged: (v) => setState(() => _type = v ?? _type),
              child: Column(
                children: [
                  for (final t in ViolationType.values)
                    RadioListTile<ViolationType>(
                      value: t,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: AppColors.primary600,
                      title: Text(t.label),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Mô tả thêm (không bắt buộc)',
              ),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Gửi báo cáo',
              loading: _sending,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
