import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/exam_models.dart';
import '../../../data/models/subject_model.dart';
import '../../../data/repositories/exam_repository.dart';
import '../../../data/repositories/subject_repository.dart';
import '../../question_bank/cubit/load_cubit.dart';

/// Giới hạn số câu của một đề (backend chưa công bố).
class ExamLimits {
  ExamLimits._();

  static const int minQuestions = 1;
  static const int maxQuestions = 100;
  static const int defaultQuestions = 20;
}

/// Kiểm tra tham số sinh đề. Trả về câu báo lỗi đầu tiên hoặc null.
String? validateExamInput(GenerateExamInput input) {
  if (input.subjectId <= 0) return 'Hãy chọn môn học.';
  if (input.classIds.isEmpty) return 'Hãy chọn ít nhất một lớp học phần.';
  if (input.questionCount < ExamLimits.minQuestions ||
      input.questionCount > ExamLimits.maxQuestions) {
    return 'Số câu phải từ ${ExamLimits.minQuestions} đến '
        '${ExamLimits.maxQuestions}.';
  }
  final d = input.difficulty;
  if (d != null && !d.isValid) {
    return 'Tổng tỉ lệ độ khó phải bằng 100%.';
  }
  return null;
}

class ExamGeneratorState extends Equatable {
  final LoadStatus status;
  final List<SubjectModel> subjects;
  final List<CourseClassModel> classes;
  final bool generating;
  final ApiException? error;

  const ExamGeneratorState({
    this.status = LoadStatus.loading,
    this.subjects = const [],
    this.classes = const [],
    this.generating = false,
    this.error,
  });

  /// Chỉ các môn mình đang dạy ít nhất một lớp (đề phải gán cho lớp).
  List<SubjectModel> get teachingSubjects => [
    for (final s in subjects)
      if (classes.any((c) => c.subjectId == s.subjectId)) s,
  ];

  List<CourseClassModel> classesOf(int? subjectId) => [
    for (final c in classes)
      if (c.subjectId == subjectId) c,
  ];

  ExamGeneratorState copyWith({
    LoadStatus? status,
    List<SubjectModel>? subjects,
    List<CourseClassModel>? classes,
    bool? generating,
    ApiException? error,
  }) => ExamGeneratorState(
    status: status ?? this.status,
    subjects: subjects ?? this.subjects,
    classes: classes ?? this.classes,
    generating: generating ?? this.generating,
    error: error ?? this.error,
  );

  @override
  List<Object?> get props => [status, subjects, classes, generating, error];
}

/// Sinh đề (chỉ giảng viên): tải môn + lớp đang dạy, kiểm tra rồi gọi API.
class ExamGeneratorCubit extends Cubit<ExamGeneratorState> {
  final ExamRepository _exams;
  final SubjectRepository _subjects;

  ExamGeneratorCubit(this._exams, this._subjects)
    : super(const ExamGeneratorState());

  Future<void> load() async {
    emit(const ExamGeneratorState());
    try {
      // Gọi song song; Future.wait ném lại lỗi gốc đầu tiên
      final results = await Future.wait<Object>([
        _subjects.all(),
        _exams.myClasses(),
      ]);
      emit(
        ExamGeneratorState(
          status: LoadStatus.loaded,
          subjects: results[0] as List<SubjectModel>,
          classes: results[1] as List<CourseClassModel>,
        ),
      );
    } on ApiException catch (e) {
      emit(ExamGeneratorState(status: LoadStatus.failure, error: e));
    }
  }

  /// Trả về đề vừa sinh, hoặc lỗi (kể cả lỗi nhập liệu) để màn hình báo.
  Future<(ExamDetail?, ApiException?)> generate(GenerateExamInput input) async {
    if (state.generating) return (null, null);
    final invalid = validateExamInput(input);
    if (invalid != null) {
      return (
        null,
        ApiException(type: ApiErrorType.validation, message: invalid),
      );
    }
    emit(state.copyWith(generating: true));
    try {
      final exam = await _exams.generate(input);
      emit(state.copyWith(generating: false));
      return (exam, null);
    } on ApiException catch (e) {
      emit(state.copyWith(generating: false));
      return (null, e);
    }
  }
}
