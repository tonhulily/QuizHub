import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/paged_cubit.dart';
import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/design_system/component_tokens.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/paged_list.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/exam_models.dart';
import '../../../data/repositories/exam_repository.dart';
import '../../../di/locator.dart';
import '../../question_bank/widgets/qbank_widgets.dart';
import '../widgets/exam_widgets.dart';

/// Đề thi giảng viên đã sinh. Chỉ giảng viên mở được màn này.
class MyExamsView extends StatefulWidget {
  const MyExamsView({super.key});

  @override
  State<MyExamsView> createState() => _MyExamsViewState();
}

class _MyExamsViewState extends State<MyExamsView> {
  late final PagedCubit<ExamSummary> _cubit = PagedCubit<ExamSummary>(
    (after) => getIt<ExamRepository>().myExams(
      after: after,
      limit: ExamRepository.maxPageSize,
    ),
  )..load();

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _generate() async {
    await Navigator.of(context).pushNamed(AppRoutes.examGenerator);
    // Màn sinh đề tự mở đề vừa tạo; quay về thì danh sách đã có đề mới
    if (mounted) _cubit.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: AppColors.backgroundSecondary,
        appBar: AppBar(title: const Text('Đề thi của tôi')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _generate,
          backgroundColor: AppColors.primary600,
          foregroundColor: AppColors.white,
          icon: const Icon(AppIcons.bolt),
          label: const Text('Sinh đề'),
        ),
        body: PagedListView<ExamSummary>(
          padding: const EdgeInsets.only(bottom: 88),
          itemSpacing: ComponentTokens.postGap,
          emptyView: const EmptyView(
            icon: AppIcons.exam,
            title: 'Chưa có đề thi nào',
            message:
                'Bấm "Sinh đề" để bốc câu hỏi đã duyệt trong ngân hàng thành '
                'một đề thi.',
          ),
          itemBuilder: (context, e) => _ExamTile(
            exam: e,
            onTap: () => Navigator.of(
              context,
            ).pushNamed(AppRoutes.examDetail, arguments: e.examId),
          ),
        ),
      ),
    );
  }
}

class _ExamTile extends StatelessWidget {
  final ExamSummary exam;
  final VoidCallback onTap;

  const _ExamTile({required this.exam, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = exam;
    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (e.subjectName != null)
                QbankChip(
                  label: e.subjectName!,
                  icon: AppIcons.subject,
                  color: AppColors.primary700,
                  background: AppColors.primary50,
                ),
              const SizedBox(height: 8),
              Text(
                e.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              DifficultyStats(statistic: e.statistic),
              const SizedBox(height: 8),
              Text(
                [
                  '${e.questionCount} câu',
                  if (e.createdAt != null) TimeFormat.dateTime(e.createdAt),
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
