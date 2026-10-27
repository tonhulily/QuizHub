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
  static const int maxOptions = 6;
  static const int maxQuestions = 50;
  static const int maxTitleLength = 200;
  static const int maxWords = 500;

  /// Bằng giới hạn ảnh của bài viết (`ComponentTokens.maxImagesPerPost`).
  static const int maxImagesPerQuestion = 4;
}

/// Kiểm tra phiên trước khi gửi. Trả về câu báo lỗi đầu tiên, hoặc null nếu
/// hợp lệ. Tách khỏi Cubit để test không cần dựng widget.
String? validateSessionDraft(SessionDraft d) {
  if (d.subjectId <= 0) return 'Hãy chọn môn học.';
  final title = d.title.trim();
  if (title.isEmpty) return 'Hãy nhập tiêu đề phiên.';
  if (title.length > SubmissionLimits.maxTitleLength) {
    return 'Tiêu đề tối đa ${SubmissionLimits.maxTitleLength} ký tự.';
  }
  final url = d.sourceUrl?.trim() ?? '';
  if (url.isNotEmpty && !RegExp(r'^https?://\S+$').hasMatch(url)) {
    return 'Link nguồn phải bắt đầu bằng http:// hoặc https://';
  }
  if (d.questions.isEmpty) return 'Phiên phải có ít nhất một câu hỏi.';
  if (d.questions.length > SubmissionLimits.maxQuestions) {
    return 'Mỗi phiên tối đa ${SubmissionLimits.maxQuestions} câu hỏi.';
  }
  for (var i = 0; i < d.questions.length; i++) {
    final q = d.questions[i];
    final n = 'Câu ${i + 1}';
    if (q.content.trim().isEmpty) return '$n: hãy nhập nội dung câu hỏi.';
    if (Validators.wordCount(q.content) > SubmissionLimits.maxWords) {
      return '$n: nội dung tối đa ${SubmissionLimits.maxWords} từ.';
    }
    if (q.mediaUrls.length > SubmissionLimits.maxImagesPerQuestion) {
      return '$n: tối đa ${SubmissionLimits.maxImagesPerQuestion} ảnh.';
    }
    if (q.options.length < SubmissionLimits.minOptions) {
      return '$n: cần ít nhất ${SubmissionLimits.minOptions} phương án.';
    }
    if (q.options.length > SubmissionLimits.maxOptions) {
      return '$n: tối đa ${SubmissionLimits.maxOptions} phương án.';
    }
    for (final o in q.options) {
      if (o.text.trim().isEmpty && o.mediaUrl == null) {
        return '$n: phương án ${o.key} đang để trống.';
      }
    }
    // Phương án chỉ có ảnh (text rỗng) không tính là trùng nhau
    final texts = [
      for (final o in q.options)
        if (o.text.trim().isNotEmpty) o.text.trim().toLowerCase(),
    ];
    if (texts.toSet().length != texts.length) {
      return '$n: có hai phương án trùng nhau.';
    }
    final correct = q.options.where((o) => o.isCorrect == true).length;
    if (correct != 1) return '$n: hãy chọn đúng một đáp án đúng.';
    final c = q.confidence;
    if (c != null && (c < 0 || c > 4)) {
      return '$n: độ tự tin phải trong khoảng 0 - 4.';
    }
  }
  return null;
}

class SubmissionFormState extends Equatable {
  final LoadStatus subjectsStatus;
  final List<SubjectModel> subjects;
  final bool saving;
  final ApiException? error;

  const SubmissionFormState({
    this.subjectsStatus = LoadStatus.loading,
    this.subjects = const [],
    this.saving = false,
    this.error,
  });

  SubmissionFormState copyWith({
    LoadStatus? subjectsStatus,
    List<SubjectModel>? subjects,
    bool? saving,
    ApiException? error,
  }) => SubmissionFormState(
    subjectsStatus: subjectsStatus ?? this.subjectsStatus,
    subjects: subjects ?? this.subjects,
    saving: saving ?? this.saving,
    error: error ?? this.error,
  );

  @override
  List<Object?> get props => [subjectsStatus, subjects, saving, error];
}

/// Tạo phiên mới ([sessionId] null) hoặc sửa phiên còn chờ duyệt.
class SubmissionFormCubit extends Cubit<SubmissionFormState> {
  final SubmissionRepository _submissions;
  final SubjectRepository _subjects;
  final int? sessionId;

  /// Môn của phiên đang sửa: vẫn hiện trong danh sách dù đã thôi học môn đó.
  final SubjectModel? currentSubject;

  SubmissionFormCubit(
    this._submissions,
    this._subjects, {
    this.sessionId,
    this.currentSubject,
  }) : super(const SubmissionFormState());

  bool get isEdit => sessionId != null;

  /// Chỉ đề xuất được cho môn đang học (môn khác server trả 403).
  Future<void> loadSubjects() async {
    emit(state.copyWith(subjectsStatus: LoadStatus.loading));
    try {
      final list = await _subjects.enrolled();
      if (isClosed) return;
      final current = currentSubject;
      emit(
        state.copyWith(
          subjectsStatus: LoadStatus.loaded,
          subjects: [
            if (current != null &&
                list.every((s) => s.subjectId != current.subjectId))
              current,
            ...list,
          ],
        ),
      );
    } on ApiException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(subjectsStatus: LoadStatus.failure, error: e));
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
