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
import '../../../data/models/subject_model.dart';
import '../../../data/repositories/exam_repository.dart';
import '../../../data/repositories/subject_repository.dart';
import '../../../di/locator.dart';
import '../../question_bank/cubit/load_cubit.dart';
import '../../question_bank/widgets/qbank_widgets.dart';
import '../widgets/exam_widgets.dart';

/// Đề thi giảng viên đã sinh. Chỉ giảng viên mở được màn này.
class MyExamsView extends StatefulWidget {
  const MyExamsView({super.key});

  @override
  State<MyExamsView> createState() => _MyExamsViewState();
}

class _MyExamsViewState extends State<MyExamsView> {
  /// Môn đang lọc; null = tất cả.
  int? _subjectId;

  late final PagedCubit<ExamSummary> _cubit = PagedCubit<ExamSummary>(
    (after) => getIt<ExamRepository>().myExams(
      after: after,
      limit: ExamRepository.maxPageSize,
      subjectId: _subjectId,
    ),
  )..load();

  /// Chip lọc: các môn mình dạy ít nhất một lớp (như màn Sinh đề).
  late final LoadCubit<List<SubjectModel>> _subjects = LoadCubit(() async {
    final r = await Future.wait<Object>([
      getIt<SubjectRepository>().all(),
      getIt<ExamRepository>().myClasses(),
    ]);
    final classes = r[1] as List<CourseClassModel>;
    return [
      for (final s in r[0] as List<SubjectModel>)
        if (classes.any((c) => c.subjectId == s.subjectId)) s,
    ];
  })..load();

  @override
  void dispose() {
    _cubit.close();
    _subjects.close();
    super.dispose();
  }

  void _filter(int? subjectId) {
    if (subjectId == _subjectId) return;
    setState(() => _subjectId = subjectId);
    _cubit
      ..reset()
      ..load();
  }

  Future<void> _generate() async {
    await Navigator.of(context).pushNamed(AppRoutes.examGenerator);
    // Màn sinh đề tự mở đề vừa tạo; quay về thì danh sách đã có đề mới
    if (mounted) _cubit.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _cubit),
        BlocProvider.value(value: _subjects),
      ],
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
          header: _SubjectFilter(selected: _subjectId, onSelected: _filter),
          emptyView: EmptyView(
            icon: AppIcons.exam,
            title: _subjectId == null
                ? 'Chưa có đề thi nào'
                : 'Chưa có đề thi của môn này',
            message:
                'Bấm "Sinh đề" để bốc câu hỏi đã duyệt trong ngân hàng thành '
                'một đề thi.',
            compact: true,
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

/// Hàng chip lọc theo môn: "Tất cả" + các môn mình dạy.
class _SubjectFilter extends StatelessWidget {
  final int? selected;
  final ValueChanged<int?> onSelected;

  const _SubjectFilter({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<
      LoadCubit<List<SubjectModel>>,
      LoadState<List<SubjectModel>>
    >(
      builder: (context, state) {
        final subjects = state.data ?? const <SubjectModel>[];
        // Lỗi / chưa dạy môn nào thì không cần lọc
        if (subjects.isEmpty) return const SizedBox.shrink();
        Widget chip(String label, int? id, {String? tooltip}) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            tooltip: tooltip,
            selected: selected == id,
            showCheckmark: false,
            selectedColor: AppColors.primary50,
            labelStyle: theme.textTheme.labelLarge?.copyWith(
              color: selected == id
                  ? AppColors.primary700
                  : AppColors.textPrimary,
            ),
            onSelected: (_) => onSelected(id),
          ),
        );
        return Container(
          color: AppColors.white,
          margin: const EdgeInsets.only(bottom: ComponentTokens.postGap),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacingMD,
            vertical: 10,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                chip('Tất cả', null),
                for (final s in subjects)
                  chip(s.code, s.subjectId, tooltip: s.name),
              ],
            ),
          ),
        );
      },
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
