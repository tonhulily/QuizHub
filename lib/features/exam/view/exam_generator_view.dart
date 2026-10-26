import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/fb_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/exam_models.dart';
import '../../../data/models/question_models.dart';
import '../../../data/repositories/exam_repository.dart';
import '../../../data/repositories/subject_repository.dart';
import '../../../di/locator.dart';
import '../../question_bank/cubit/load_cubit.dart';
import '../../question_bank/widgets/qbank_widgets.dart';
import '../cubit/exam_generator_cubit.dart';
import '../widgets/exam_widgets.dart';

/// Sinh đề từ ngân hàng câu hỏi đã duyệt (chỉ giảng viên). Sinh xong thay
/// màn này bằng màn xem trước đề.
class ExamGeneratorView extends StatelessWidget {
  const ExamGeneratorView({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        ExamGeneratorCubit(getIt<ExamRepository>(), getIt<SubjectRepository>())
          ..load(),
    child: const _GeneratorForm(),
  );
}

class _GeneratorForm extends StatefulWidget {
  const _GeneratorForm();

  @override
  State<_GeneratorForm> createState() => _GeneratorFormState();
}

class _GeneratorFormState extends State<_GeneratorForm> {
  final _title = TextEditingController();
  final _count = TextEditingController(text: '${ExamLimits.defaultQuestions}');
  int? _subjectId;
  final Set<int> _classIds = {};
  bool _shuffle = true;
  bool _answerKey = false;

  /// Tắt = để backend tự bốc theo mọi độ khó.
  bool _customDifficulty = false;

  /// Phần trăm, bước 5. "Chưa phân loại" là phần còn lại.
  int _easy = 30, _medium = 50, _hard = 20;

  int get _unclassified => 100 - _easy - _medium - _hard;

  @override
  void dispose() {
    _title.dispose();
    _count.dispose();
    super.dispose();
  }

  void _pickSubject(int? id, ExamGeneratorState state) {
    setState(() {
      _subjectId = id;
      // Mặc định chọn sẵn mọi lớp của môn: thường đề dùng chung cho các lớp
      _classIds
        ..clear()
        ..addAll(state.classesOf(id).map((c) => c.courseClassId));
    });
  }

  GenerateExamInput _input() => GenerateExamInput(
    subjectId: _subjectId ?? 0,
    title: _title.text,
    questionCount: int.tryParse(_count.text.trim()) ?? 0,
    difficulty: _customDifficulty
        ? DifficultyRatio(
            easy: _easy / 100,
            medium: _medium / 100,
            hard: _hard / 100,
            unclassified: _unclassified / 100,
          )
        : null,
    shuffleOptions: _shuffle,
    includeAnswerKey: _answerKey,
    classIds: _classIds.toList(),
  );

  Future<void> _generate() async {
    FocusScope.of(context).unfocus();
    final (exam, error) = await context.read<ExamGeneratorCubit>().generate(
      _input(),
    );
    if (!mounted) return;
    if (error != null) {
      AppFeedback.error(context, error);
      return;
    }
    if (exam == null) return;
    // Ngân hàng của môn không đủ câu đã duyệt: backend vẫn sinh đề ít câu hơn
    final requested = _input().questionCount;
    if (exam.questions.length < requested) {
      AppFeedback.info(
        context,
        'Ngân hàng chỉ có ${exam.questions.length}/$requested câu phù hợp, '
        'đề được sinh với số câu hiện có.',
      );
    }
    Navigator.of(
      context,
    ).pushReplacementNamed(AppRoutes.examDetail, arguments: exam);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<ExamGeneratorCubit, ExamGeneratorState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.backgroundSecondary,
          appBar: AppBar(title: const Text('Sinh đề thi')),
          body: switch (state.status) {
            LoadStatus.loading => const LoadingView(),
            LoadStatus.failure => ErrorView(
              error: state.error,
              onRetry: context.read<ExamGeneratorCubit>().load,
            ),
            LoadStatus.loaded when state.teachingSubjects.isEmpty =>
              const EmptyView(
                icon: AppIcons.classGroup,
                title: 'Bạn chưa phụ trách lớp nào',
                message:
                    'Đề thi phải gán cho ít nhất một lớp học phần bạn đang '
                    'dạy trong học kỳ này.',
              ),
            LoadStatus.loaded => GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  QbankBlock(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: _subjectId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Môn học *',
                            prefixIcon: Icon(AppIcons.subject),
                          ),
                          items: [
                            for (final s in state.teachingSubjects)
                              DropdownMenuItem(
                                value: s.subjectId,
                                child: Text(
                                  s.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (id) => _pickSubject(id, state),
                        ),
                        if (_subjectId != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Lớp học phần áp dụng *',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final c in state.classesOf(_subjectId))
                                FilterChip(
                                  label: Text(
                                    [
                                      c.classCode,
                                      if (c.semesterName != null)
                                        c.semesterName!,
                                      '${c.totalStudents} SV',
                                    ].join(' · '),
                                  ),
                                  selected: _classIds.contains(c.courseClassId),
                                  onSelected: (v) => setState(
                                    () => v
                                        ? _classIds.add(c.courseClassId)
                                        : _classIds.remove(c.courseClassId),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _title,
                          label: 'Tên đề (tuỳ chọn)',
                          hint: 'Bỏ trống để hệ thống tự đặt tên',
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _count,
                          label:
                              'Số câu (${ExamLimits.minQuestions} - '
                              '${ExamLimits.maxQuestions}) *',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SectionGap(),
                  QbankBlock(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Tuỳ chỉnh tỉ lệ độ khó'),
                          subtitle: Text(
                            _customDifficulty
                                ? 'Phần còn lại là câu chưa phân loại.'
                                : 'Tắt: bốc ngẫu nhiên mọi độ khó.',
                          ),
                          value: _customDifficulty,
                          onChanged: (v) =>
                              setState(() => _customDifficulty = v),
                        ),
                        if (_customDifficulty) ...[
                          _RatioSlider(
                            difficulty: Difficulty.easy,
                            value: _easy,
                            onChanged: (v) => setState(() => _easy = v),
                          ),
                          _RatioSlider(
                            difficulty: Difficulty.medium,
                            value: _medium,
                            onChanged: (v) => setState(() => _medium = v),
                          ),
                          _RatioSlider(
                            difficulty: Difficulty.hard,
                            value: _hard,
                            onChanged: (v) => setState(() => _hard = v),
                          ),
                          const SizedBox(height: 4),
                          _unclassified < 0
                              ? ExplanationBox(
                                  title:
                                      'Tổng đang là '
                                      '${100 - _unclassified}%, vượt 100%',
                                  text: 'Giảm bớt một mức độ khó.',
                                  icon: AppIcons.error,
                                  color: AppColors.errorDark,
                                  background: AppColors.errorLight,
                                )
                              : Text(
                                  'Chưa phân loại: $_unclassified%',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                        ],
                      ],
                    ),
                  ),
                  const SectionGap(),
                  QbankBlock(
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Trộn thứ tự phương án'),
                          value: _shuffle,
                          onChanged: (v) => setState(() => _shuffle = v),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Kèm bảng đáp án'),
                          value: _answerKey,
                          onChanged: (v) => setState(() => _answerKey = v),
                        ),
                      ],
                    ),
                  ),
                  const SectionGap(),
                  QbankBlock(
                    child: AppButton(
                      label: 'Sinh đề',
                      icon: AppIcons.bolt,
                      loading: state.generating,
                      onPressed: _generate,
                    ),
                  ),
                ],
              ),
            ),
          },
        );
      },
    );
  }
}

class _RatioSlider extends StatelessWidget {
  final Difficulty difficulty;
  final int value;
  final ValueChanged<int> onChanged;

  const _RatioSlider({
    required this.difficulty,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final (fg, _) = difficultyColors(difficulty);
    return Row(
      children: [
        SizedBox(width: 90, child: DifficultyChip(difficulty: difficulty)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            max: 100,
            divisions: 20,
            label: '$value%',
            activeColor: fg,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '$value%',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    );
  }
}
