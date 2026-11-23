import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/session_models.dart';
import '../../../data/models/subject_model.dart';
import '../../../data/repositories/subject_repository.dart';
import '../../../data/repositories/submission_repository.dart';
import 'load_cubit.dart';

/// Giới hạn của form đề xuất (backend chưa công bố, chọn theo đề thi giấy).
class SubmissionLimits {
  SubmissionLimits._();

  static const int minOptions = 2;

  /// `ProposeSessionRequest.questions` có `minItems: 3` trên Swagger.
  static const int minQuestions = 3;
  static const int maxOptions = 6;
  static const int maxQuestions = 50;
  static const int maxTitleLength = 200;
  static const int maxWords = 500;

  /// Bằng giới hạn ảnh của bài viết (`ComponentTokens.maxImagesPerPost`).
  static const int maxImagesPerQuestion = 4;
}

/// Ô bị lỗi trong form đề xuất.
enum DraftField {
  /// Lớp học phần nhận phiên.
  courseClass,
  title,
  source,

  /// Số câu của phiên (chưa có câu nào / quá nhiều câu).
  questions,
  content,
  images,

  /// Một phương án ([DraftIssue.option]) hoặc cả nhóm phương án (thiếu / thừa).
  options,
  correct,
  confidence,
}

/// Lỗi nhập liệu đầu tiên của phiên, kèm vị trí để form viền đỏ và cuộn tới.
class DraftIssue extends Equatable {
  final String message;
  final DraftField field;

  /// Chỉ số câu hỏi (từ 0), null nếu lỗi ở phần thông tin phiên.
  final int? question;

  /// Chỉ số phương án (từ 0), chỉ có khi lỗi ở một phương án cụ thể.
  final int? option;

  const DraftIssue(this.message, this.field, {this.question, this.option});

  /// Cùng một ô (nội dung lỗi có thể khác).
  bool sameSpot(DraftIssue? o) =>
      o != null &&
      o.field == field &&
      o.question == question &&
      o.option == option;

  @override
  List<Object?> get props => [message, field, question, option];
}

/// Kiểm tra phiên trước khi gửi. Trả về câu báo lỗi đầu tiên, hoặc null nếu
/// hợp lệ. Tách khỏi Cubit để test không cần dựng widget.
String? validateSessionDraft(SessionDraft d) => checkSessionDraft(d)?.message;

/// Như [validateSessionDraft] nhưng cho biết lỗi nằm ở ô nào.
DraftIssue? checkSessionDraft(SessionDraft d) {
  if (d.courseClassId <= 0) {
    return const DraftIssue('Hãy chọn lớp học phần.', DraftField.courseClass);
  }
  final title = d.title.trim();
  if (title.isEmpty) {
    return const DraftIssue('Hãy nhập tiêu đề phiên.', DraftField.title);
  }
  if (title.length > SubmissionLimits.maxTitleLength) {
    return const DraftIssue(
      'Tiêu đề tối đa ${SubmissionLimits.maxTitleLength} ký tự.',
      DraftField.title,
    );
  }
  final url = d.sourceUrl?.trim() ?? '';
  if (url.isNotEmpty && !RegExp(r'^https?://\S+$').hasMatch(url)) {
    return const DraftIssue(
      'Link nguồn phải bắt đầu bằng http:// hoặc https://',
      DraftField.source,
    );
  }
  if (d.questions.length < SubmissionLimits.minQuestions) {
    return const DraftIssue(
      'Phiên phải có ít nhất ${SubmissionLimits.minQuestions} câu hỏi.',
      DraftField.questions,
    );
  }
  if (d.questions.length > SubmissionLimits.maxQuestions) {
    return const DraftIssue(
      'Mỗi phiên tối đa ${SubmissionLimits.maxQuestions} câu hỏi.',
      DraftField.questions,
    );
  }
  for (var i = 0; i < d.questions.length; i++) {
    final q = d.questions[i];
    final n = 'Câu ${i + 1}';
    DraftIssue at(String m, DraftField f, {int? option}) =>
        DraftIssue('$n: $m', f, question: i, option: option);

    if (q.content.trim().isEmpty) {
      return at('hãy nhập nội dung câu hỏi.', DraftField.content);
    }
    if (Validators.wordCount(q.content) > SubmissionLimits.maxWords) {
      return at(
        'nội dung tối đa ${SubmissionLimits.maxWords} từ.',
        DraftField.content,
      );
    }
    if (q.mediaUrls.length > SubmissionLimits.maxImagesPerQuestion) {
      return at(
        'tối đa ${SubmissionLimits.maxImagesPerQuestion} ảnh.',
        DraftField.images,
      );
    }
    if (q.options.length < SubmissionLimits.minOptions) {
      return at(
        'cần ít nhất ${SubmissionLimits.minOptions} phương án.',
        DraftField.options,
      );
    }
    if (q.options.length > SubmissionLimits.maxOptions) {
      return at(
        'tối đa ${SubmissionLimits.maxOptions} phương án.',
        DraftField.options,
      );
    }
    for (var j = 0; j < q.options.length; j++) {
      final o = q.options[j];
      if (o.text.trim().isEmpty && o.mediaUrl == null) {
        return at(
          'phương án ${o.key} đang để trống.',
          DraftField.options,
          option: j,
        );
      }
    }
    // Phương án chỉ có ảnh (text rỗng) không tính là trùng nhau
    final seen = <String>{};
    for (var j = 0; j < q.options.length; j++) {
      final t = q.options[j].text.trim().toLowerCase();
      if (t.isNotEmpty && !seen.add(t)) {
        return at(
          'có hai phương án trùng nhau.',
          DraftField.options,
          option: j,
        );
      }
    }
    final correct = q.options.where((o) => o.isCorrect == true).length;
    if (correct != 1) {
      return at('hãy chọn đúng một đáp án đúng.', DraftField.correct);
    }
    final c = q.confidence;
    if (c != null && (c < 0 || c > 4)) {
      return at('độ tự tin phải trong khoảng 0 - 4.', DraftField.confidence);
    }
  }
  return null;
}

class SubmissionFormState extends Equatable {
  final LoadStatus classesStatus;

  /// Lớp học phần được chọn để đề xuất (học kỳ hiện tại, `can_propose`).
  final List<EnrolledCourseClass> classes;
  final bool saving;
  final ApiException? error;

  const SubmissionFormState({
    this.classesStatus = LoadStatus.loading,
    this.classes = const [],
    this.saving = false,
    this.error,
  });

  SubmissionFormState copyWith({
    LoadStatus? classesStatus,
    List<EnrolledCourseClass>? classes,
    bool? saving,
    ApiException? error,
  }) => SubmissionFormState(
    classesStatus: classesStatus ?? this.classesStatus,
    classes: classes ?? this.classes,
    saving: saving ?? this.saving,
    error: error ?? this.error,
  );

  @override
  List<Object?> get props => [classesStatus, classes, saving, error];
}

/// Tạo phiên mới ([sessionId] null) hoặc sửa phiên còn chờ duyệt.
class SubmissionFormCubit extends Cubit<SubmissionFormState> {
  final SubmissionRepository _submissions;
  final SubjectRepository _subjects;
  final int? sessionId;

  /// Lớp của phiên đang sửa: vẫn hiện trong danh sách dù không còn
  /// `can_propose` (đổi học kỳ).
  final EnrolledCourseClass? currentClass;

  SubmissionFormCubit(
    this._submissions,
    this._subjects, {
    this.sessionId,
    this.currentClass,
  }) : super(const SubmissionFormState());

  bool get isEdit => sessionId != null;

  /// Chỉ đề xuất được vào lớp học phần của học kỳ hiện tại
  /// (`can_propose` = true); lớp khác server từ chối.
  Future<void> loadClasses() async {
    emit(state.copyWith(classesStatus: LoadStatus.loading));
    try {
      final list = (await _subjects.enrolledClasses())
          .where((c) => c.canPropose)
          .toList();
      if (isClosed) return;
      final current = currentClass;
      emit(
        state.copyWith(
          classesStatus: LoadStatus.loaded,
          classes: [
            if (current != null &&
                list.every((c) => c.courseClassId != current.courseClassId))
              current,
            ...list,
          ],
        ),
      );
    } on ApiException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(classesStatus: LoadStatus.failure, error: e));
    }
  }

  /// Kiểm tra rồi gửi. Trả về lỗi (kể cả lỗi nhập liệu) để màn hình báo.
  Future<ApiException?> submit(SessionDraft draft) async {
    if (state.saving) return null;
    final invalid = validateSessionDraft(draft);
    if (invalid != null) {
      return ApiException(type: ApiErrorType.validation, message: invalid);
    }
    emit(state.copyWith(saving: true));
    try {
      final id = sessionId;
      if (id == null) {
        await _submissions.propose(draft);
      } else {
        await _submissions.update(id, draft);
      }
      if (!isClosed) emit(state.copyWith(saving: false));
      return null;
    } on ApiException catch (e) {
      if (!isClosed) emit(state.copyWith(saving: false));
      return e;
    }
  }
}
