import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/ai_models.dart';
import '../../../data/models/auth_session.dart';
import '../../../data/models/exam_models.dart';
import '../../../data/models/question_models.dart';
import '../../../data/models/session_models.dart';
import '../../../data/repositories/ai_repository.dart';
import '../../../data/repositories/submission_repository.dart';
import 'submission_form_cubit.dart';

/// Vai trò được ghi đè câu hỏi bằng bản AI (`ai-apply`): theo Swagger là
/// "Giảng viên / Người kiểm duyệt".
bool canApplyAi(UserRole? role) =>
    role == UserRole.lecturer || role == UserRole.admin;

/// Câu hỏi đem đi nhờ AI. Lấy được từ mọi màn có câu hỏi đã có id (phiên của
/// mình, luyện tập, đề thi).
class AiTarget extends Equatable {
  final int questionId;

  /// Tiêu đề màn hình, vd "Câu 3"
  final String label;
  final String content;
  final List<String> imageUrls;
  final List<QuestionOption> options;
  final String? explanation;

  const AiTarget({
    required this.questionId,
    required this.label,
    required this.content,
    this.imageUrls = const [],
    this.options = const [],
    this.explanation,
  });

  factory AiTarget.fromSubmission(SubmissionQuestion q, int index) => AiTarget(
    questionId: q.questionId,
    label: 'Câu ${index + 1}',
    content: q.content,
    imageUrls: q.imageUrls,
    options: q.options,
    explanation: q.explanation,
  );

  /// Câu luyện tập chưa trả lời bị ẩn đáp án: màn AI hiện đúng như vậy.
  factory AiTarget.fromPractice(PracticeQuestion q, int index) => AiTarget(
    questionId: q.questionId,
    label: q.questionCode ?? 'Câu ${index + 1}',
    content: q.content,
    imageUrls: q.imageUrls,
    options: q.options,
    explanation: q.explanation,
  );

  factory AiTarget.fromExam(ExamQuestion q) => AiTarget(
    questionId: q.questionId,
    label: 'Câu ${q.order}',
    content: q.content,
    imageUrls: q.imageUrls,
    options: q.options,
  );

  @override
  List<Object?> get props => [questionId, content, options, explanation];
}

/// Tham số route `AppRoutes.qbankAiRefine`.
class AiRefineArgs {
  final AiTarget target;

  /// Phiên CỦA MÌNH đang chờ duyệt chứa câu này (chỉ khi mở từ chi tiết
  /// phiên): sinh viên lưu bản AI bằng cách sửa phiên.
  final SubmissionDetail? session;
  final int? questionIndex;

  const AiRefineArgs(this.target, {this.session, this.questionIndex})
    : assert(
        (session == null) == (questionIndex == null),
        'session và questionIndex phải đi cùng nhau',
      );

  factory AiRefineArgs.fromSession(SubmissionDetail d, int index) =>
      AiRefineArgs(
        AiTarget.fromSubmission(d.questions[index], index),
        session: d,
        questionIndex: index,
      );
}

enum AiRefineStatus { idle, refining, ready, saving }

class AiRefineState extends Equatable {
  final AiRefineStatus status;
  final AiRefineResult? result;

  const AiRefineState({this.status = AiRefineStatus.idle, this.result});

  bool get busy =>
      status == AiRefineStatus.refining || status == AiRefineStatus.saving;

  /// Có bản gợi ý dùng được (AI không từ chối).
  bool get hasSuggestion => result != null && !result!.refused;

  @override
  List<Object?> get props => [status, result];
}

/// Nhờ AI tinh chỉnh MỘT câu hỏi rồi quyết định giữ / bỏ.
///
/// - Giảng viên / admin: `ai-apply` ghi đè câu gốc trong ngân hàng.
/// - Sinh viên không được gọi `ai-apply`: chỉ giữ được bản AI cho câu trong
///   phiên của mình còn chờ duyệt, bằng `PUT` sửa phiên như khi tự sửa.
class AiRefineCubit extends Cubit<AiRefineState> {
  final AiRepository _ai;
  final SubmissionRepository _submissions;
  final AiRefineArgs args;
  final bool canApply;

  AiRefineCubit(
    this._ai,
    this._submissions, {
    required this.args,
    required this.canApply,
  }) : super(const AiRefineState());

  AiTarget get target => args.target;

  /// Có cách nào giữ bản gợi ý không (ngược lại chỉ xem để tham khảo).
  bool get canAccept => canApply || args.session != null;

  static ApiException _invalid(String message) =>
      ApiException(type: ApiErrorType.validation, message: message);

  Future<ApiException?> refine(String prompt) async {
    if (state.busy) return null;
    final p = prompt.trim();
    if (p.isEmpty) return _invalid('Hãy nhập yêu cầu cho AI.');
    if (p.length > AiRepository.maxPromptLength) {
      return _invalid('Yêu cầu tối đa ${AiRepository.maxPromptLength} ký tự.');
    }
    emit(AiRefineState(status: AiRefineStatus.refining, result: state.result));
    try {
      final r = await _ai.refine(target.questionId, prompt: p);
      if (isClosed) return null;
      emit(AiRefineState(status: AiRefineStatus.ready, result: r));
      return null;
    } on ApiException catch (e) {
      if (isClosed) return e;
      emit(AiRefineState(status: _settled, result: state.result));
      if (e.code == 'CONTENT_VIOLATES_POLICY') {
        return ApiException(
          type: e.type,
          code: e.code,
          statusCode: e.statusCode,
          message:
              'Yêu cầu bị chặn vì vi phạm chính sách nội dung. Hãy viết lại '
              'yêu cầu (chỉ nói về cách sửa câu hỏi).',
        );
      }
      return e;
    }
  }

  AiRefineStatus get _settled =>
      state.result == null ? AiRefineStatus.idle : AiRefineStatus.ready;

  /// Giữ bản gợi ý. Trả về null nếu đã lưu thành công.
  Future<ApiException?> accept() async {
    final r = state.result;
    if (r == null || r.refused || state.busy) return null;
    if (!canAccept) {
      return const ApiException(
        type: ApiErrorType.forbidden,
        message: 'Chỉ giảng viên mới áp dụng được bản AI cho câu hỏi này.',
      );
    }
    emit(AiRefineState(status: AiRefineStatus.saving, result: r));
    try {
      if (canApply) {
        await _ai.apply(
          target.questionId,
          editLogId: r.editLogId,
          approve: true,
        );
      } else {
        final draft = _draftWith(r);
        final invalid = validateSessionDraft(draft);
        if (invalid != null) {
          emit(AiRefineState(status: AiRefineStatus.ready, result: r));
          return _invalid('Bản gợi ý chưa hợp lệ: $invalid');
        }
        await _submissions.update(args.session!.sessionId, draft);
      }
      if (isClosed) return null;
      emit(AiRefineState(status: AiRefineStatus.ready, result: r));
      return null;
    } on ApiException catch (e) {
      if (isClosed) return e;
      emit(AiRefineState(status: AiRefineStatus.ready, result: r));
      return e;
    }
  }

  /// Bỏ bản gợi ý. Giảng viên báo cho server để đóng nhật ký chỉnh sửa;
  /// sinh viên chỉ cần đóng màn hình (server không cho gọi `ai-apply`).
  Future<ApiException?> discard() async {
    final r = state.result;
    if (r == null || r.refused || !canApply) return null;
    try {
      await _ai.apply(
        target.questionId,
        editLogId: r.editLogId,
        approve: false,
      );
      return null;
    } on ApiException catch (e) {
      return e;
    }
  }

  /// Phiên hiện tại, thay câu đang chỉnh bằng bản AI (giữ ảnh, nguồn, độ tự
  /// tin của tác giả).
  SessionDraft _draftWith(AiRefineResult r) {
    final base = SessionDraft.fromDetail(args.session!);
    final i = args.questionIndex!;
    final questions = [...base.questions];
    final old = questions[i];
    questions[i] = QuestionDraft(
      questionId: old.questionId,
      content: r.content,
      mediaUrls: old.mediaUrls,
      options: r.options,
      explanation: r.explanation,
      source: old.source,
      confidence: old.confidence,
    );
    return SessionDraft(
      subjectId: base.subjectId,
      title: base.title,
      content: base.content,
      sourceUrl: base.sourceUrl,
      questions: questions,
    );
  }
}
