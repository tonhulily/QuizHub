import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/question_models.dart';
import '../../../data/models/session_models.dart';
import '../../../data/repositories/question_bank_repository.dart';
import 'load_cubit.dart';

class PracticeState extends Equatable {
  final LoadStatus status;
  final SessionQuestions? session;
  final List<PracticeQuestion> questions;
  final int index;

  /// Đáp án đang chọn của từng câu (chưa nộp): questionId -> khoá
  final Map<int, String> selected;

  /// Kết quả chấm trong lần làm này: questionId -> kết quả. Câu đã làm từ
  /// trước thì không có ở đây (server không trả lại lựa chọn cũ).
  final Map<int, AnswerResult> results;
  final bool submitting;
  final ApiException? error;

  const PracticeState({
    this.status = LoadStatus.loading,
    this.session,
    this.questions = const [],
    this.index = 0,
    this.selected = const {},
    this.results = const {},
    this.submitting = false,
    this.error,
  });

  PracticeQuestion? get current =>
      index < questions.length ? questions[index] : null;

  int get answeredCount => questions.where((q) => q.answered).length;

  int get correctCount => results.values.where((r) => r.isCorrect).length;

  /// Khoá đáp án đúng của [q]; rỗng nếu backend còn ẩn (chưa trả lời).
  List<String> correctKeysOf(PracticeQuestion q) {
    final r = results[q.questionId];
    if (r != null) return r.correctKeys;
    final raw = q.correctAnswer;
    if (raw != null && raw.isNotEmpty) {
      return [
        for (final k in raw.split(','))
          if (k.trim().isNotEmpty) k.trim(),
      ];
    }
    return [
      for (final o in q.options)
        if (o.isCorrect == true) o.key,
    ];
  }

  PracticeState copyWith({
    LoadStatus? status,
    SessionQuestions? session,
    List<PracticeQuestion>? questions,
    int? index,
    Map<int, String>? selected,
    Map<int, AnswerResult>? results,
    bool? submitting,
    ApiException? error,
    bool clearError = false,
  }) => PracticeState(
    status: status ?? this.status,
    session: session ?? this.session,
    questions: questions ?? this.questions,
    index: index ?? this.index,
    selected: selected ?? this.selected,
    results: results ?? this.results,
    submitting: submitting ?? this.submitting,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => [
    status,
    session,
    questions,
    index,
    selected,
    results,
    submitting,
    error,
  ];
}

/// Làm lần lượt các câu của một phiên: chọn, nộp, đánh giá.
///
/// Mỗi câu chỉ trả lời được MỘT lần (server trả 409 nếu nộp lại).
class PracticeCubit extends Cubit<PracticeState> {
  final QuestionBankRepository _repo;
  final int sessionId;

  /// Mở phiên từ kết quả tìm câu hỏi: lần tải đầu nhảy tới câu này.
  final int? focusQuestionId;

  PracticeCubit(this._repo, this.sessionId, {this.focusQuestionId})
    : super(const PracticeState());

  Future<void> load({bool silent = false}) async {
    if (!silent) emit(const PracticeState());
    try {
      final s = await _repo.sessionQuestions(sessionId);
      if (isClosed) return;
      final index = state.index < s.questions.length ? state.index : 0;
      emit(
        state.copyWith(
          status: LoadStatus.loaded,
          session: s,
          questions: s.questions,
          index: silent ? index : _startIndex(s.questions),
          clearError: true,
        ),
      );
    } on ApiException catch (e) {
      if (isClosed || (silent && state.session != null)) return;
      emit(PracticeState(status: LoadStatus.failure, error: e));
    }
  }

  /// Câu cần mở ([focusQuestionId]) nếu có trong phiên; không thì mở lại phiên
  /// làm dở ở câu đầu tiên chưa làm.
  int _startIndex(List<PracticeQuestion> qs) {
    final focus = qs.indexWhere((q) => q.questionId == focusQuestionId);
    if (focus >= 0) return focus;
    final i = qs.indexWhere((q) => !q.answered);
    return i < 0 ? 0 : i;
  }

  void goTo(int i) {
    if (i < 0 || i >= state.questions.length || i == state.index) return;
    emit(state.copyWith(index: i));
  }

  void select(String key) {
    final q = state.current;
    if (q == null || q.answered || state.submitting) return;
    emit(state.copyWith(selected: {...state.selected, q.questionId: key}));
  }

  /// Nộp đáp án của câu hiện tại. Trả về lỗi để màn hình hiển thị.
  Future<ApiException?> submit() async {
    final q = state.current;
    if (q == null || q.answered || state.submitting) return null;
    final key = state.selected[q.questionId];
    if (key == null) {
      return const ApiException(
        type: ApiErrorType.validation,
        message: 'Hãy chọn một đáp án trước khi nộp.',
      );
    }
    emit(state.copyWith(submitting: true));
    try {
      final r = await _repo.answer(q.questionId, [
        key,
      ], questionUpdatedAt: q.updatedAtRaw);
      _replace(q.withAnswer(r), result: r);
      return null;
    } on ApiException catch (e) {
      if (isClosed) return e;
      emit(state.copyWith(submitting: false));
      // 409: đã trả lời ở thiết bị khác; 412: tác giả vừa sửa câu. Cả hai
      // trường hợp dữ liệu trên máy đã cũ nên tải lại phiên.
      if (e.statusCode == 409 || e.statusCode == 412) {
        await load(silent: true);
        return ApiException(
          type: e.type,
          code: e.code,
          statusCode: e.statusCode,
          message: e.statusCode == 409
              ? 'Bạn đã trả lời câu này rồi.'
              : 'Câu hỏi vừa được tác giả sửa, đã tải lại nội dung mới.',
        );
      }
      return e;
    }
  }

  Future<ApiException?> rate({
    required int rating,
    bool isError = false,
    String? comment,
  }) async {
    final q = state.current;
    if (q == null) return null;
    try {
      final r = await _repo.rate(
        q.questionId,
        rating: rating,
        isError: isError,
        comment: comment,
      );
      _replace(q.withRating(r));
      return null;
    } on ApiException catch (e) {
      return e;
    }
  }

  void _replace(PracticeQuestion updated, {AnswerResult? result}) {
    if (isClosed) return; // trả lời / đánh giá xong khi đã rời màn hình
    final list = [
      for (final x in state.questions)
        x.questionId == updated.questionId ? updated : x,
    ];
    emit(
      state.copyWith(
        questions: list,
        submitting: false,
        results: result == null
            ? null
            : {...state.results, updated.questionId: result},
      ),
    );
  }
}
