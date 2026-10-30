import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';
import 'cursor_page.dart';
import 'question_models.dart';

/// Trạng thái phiên đề xuất: PENDING -> REVIEWING (giảng viên đã mở xem) ->
/// RESOLVED (đã xử lý xong từng câu).
enum SessionStatus {
  pending('PENDING', 'Chờ duyệt'),
  reviewing('REVIEWING', 'Đang duyệt'),
  resolved('RESOLVED', 'Đã xử lý'),

  /// Backend không gửi trạng thái, hoặc gửi giá trị app chưa biết.
  unknown('', 'Không rõ');

  final String apiValue;
  final String label;
  const SessionStatus(this.apiValue, this.label);

  /// Backend chỉ cho sửa / xoá phiên còn chờ duyệt (ngược lại trả 403).
  bool get editable => this == pending;

  /// Các giá trị dùng cho bộ lọc danh sách.
  static const filters = [pending, reviewing, resolved];

  static SessionStatus parse(dynamic v) {
    final s = J.stringOr(v).toUpperCase();
    for (final x in filters) {
      if (x.apiValue == s) return x;
    }
    return unknown;
  }
}

String? _clean(String? s) {
  final t = s?.trim();
  return t == null || t.isEmpty ? null : t;
}

/// Tóm tắt một phiên đề xuất. Dùng chung cho `GET /sessions/my-submissions`,
/// `GET /users/{id}/sessions` và kết quả tìm kiếm loại SESSION.
class SubmissionSummary extends Equatable {
  final int sessionId;
  final String? sessionCode;
  final String title;
  final String? content;
  final int? subjectId;
  final String? subjectName;
  final String? subjectCode;
  final int questionCount;

  /// Swagger của danh sách KHÔNG có trường này (chỉ có bộ lọc `status`), kết
  /// quả tìm kiếm thì có. Thiếu thì là [SessionStatus.unknown].
  final SessionStatus status;
  final DateTime? createdAt;
  final int reactCount;
  final int commentCount;

  const SubmissionSummary({
    required this.sessionId,
    this.sessionCode,
    required this.title,
    this.content,
    this.subjectId,
    this.subjectName,
    this.subjectCode,
    this.questionCount = 0,
    this.status = SessionStatus.unknown,
    this.createdAt,
    this.reactCount = 0,
    this.commentCount = 0,
  });

  factory SubmissionSummary.fromJson(Map<String, dynamic> json) =>
      SubmissionSummary(
        sessionId: J.intOr(json['session_id'] ?? json['id']),
        sessionCode: J.asString(json['session_code']),
        title: J.stringOr(json['title'], 'Phiên đề xuất'),
        content: J.asString(json['content']),
        subjectId: J.asInt(json['subject_id']),
        subjectName: J.asString(json['subject_name']),
        subjectCode: J.asString(json['subject_code']),
        // Danh sách dùng question_counts, tìm kiếm dùng question_count
        questionCount: J.intOr(
          json['question_counts'] ??
              json['question_count'] ??
              json['total_questions'],
        ),
        status: SessionStatus.parse(json['status']),
        createdAt: J.asDate(json['created_at']),
        reactCount: J.intOr(json['react_count']),
        commentCount: J.intOr(json['comment_count']),
      );

  /// Trang danh sách phiên. Backend để danh sách trong khoá `contents`
  /// (khác các API khác dùng `items`).
  static CursorPage<SubmissionSummary> pageFromJson(dynamic data) {
    final map = J.asMap(data);
    final key = map != null && map['contents'] is List ? 'contents' : 'items';
    return CursorPage.fromJson(data, SubmissionSummary.fromJson, itemsKey: key);
  }

  @override
  List<Object?> get props => [
    sessionId,
    title,
    content,
    subjectId,
    questionCount,
    status,
    reactCount,
    commentCount,
  ];
}

/// Một câu trong phiên của chính mình (`MySubmissionQuestionDto`): có đủ đáp
/// án đúng, lời giải, độ tự tin.
class SubmissionQuestion extends Equatable {
  final int questionId;
  final String content;
  final List<String> imageUrls;
  final List<QuestionOption> options;
  final String? explanation;
  final QuestionSource source;

  /// Độ tự tin của tác giả, 0.0 - 4.0
  final double? confidence;

  /// Swagger chưa có; đọc nếu JSON thật có.
  final QuestionStatus status;
  final int reactCount;
  final int commentCount;
  final int ratingCount;

  /// Mình đã Thích câu này chưa. Swagger (`MySubmissionQuestionDto`) chưa có;
  /// đọc `reacted_by_me` nếu backend trả, không thì coi như chưa.
  final bool reactedByMe;

  const SubmissionQuestion({
    required this.questionId,
    required this.content,
    this.imageUrls = const [],
    this.options = const [],
    this.explanation,
    this.source = QuestionSource.human,
    this.confidence,
    this.status = QuestionStatus.unknown,
    this.reactCount = 0,
    this.commentCount = 0,
    this.ratingCount = 0,
    this.reactedByMe = false,
  });

  factory SubmissionQuestion.fromJson(Map<String, dynamic> json) =>
      SubmissionQuestion(
        questionId: J.intOr(json['question_id'] ?? json['id']),
        content: J.stringOr(json['content']),
        imageUrls: jsonStrings(json['image_urls'] ?? json['media_urls']),
        options: J.list(json['options'], QuestionOption.fromJson),
        explanation: J.asString(json['explanation']),
        source: QuestionSource.parse(json['source']),
        confidence: J.asDouble(json['confidence_score'] ?? json['confidence']),
        status: QuestionStatus.parse(json['status']),
        reactCount: J.intOr(json['react_count']),
        commentCount: J.intOr(json['comment_count']),
        ratingCount: J.intOr(json['rating_count']),
        reactedByMe: J.asBool(json['reacted_by_me']),
      );

  @override
  List<Object?> get props => [
    questionId,
    content,
    imageUrls,
    options,
    explanation,
    source,
    confidence,
    status,
    reactCount,
    commentCount,
    ratingCount,
    reactedByMe,
  ];
}

/// Chi tiết phiên của chính mình (`GET /sessions/my-submissions/{id}`).
class SubmissionDetail extends Equatable {
  final int sessionId;
  final String? sessionCode;
  final String title;
  final String? content;
  final String? sourceUrl;
  final int? subjectId;
  final String? subjectName;
  final String? subjectCode;
  final SessionStatus status;

  /// Tên / email giảng viên đã duyệt (null nếu chưa duyệt)
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime? createdAt;
  final int reactCount;
  final int commentCount;
  final List<SubmissionQuestion> questions;

  const SubmissionDetail({
    required this.sessionId,
    this.sessionCode,
    required this.title,
    this.content,
    this.sourceUrl,
    this.subjectId,
    this.subjectName,
    this.subjectCode,
    this.status = SessionStatus.unknown,
    this.reviewedBy,
    this.reviewedAt,
    this.createdAt,
    this.reactCount = 0,
    this.commentCount = 0,
    this.questions = const [],
  });

  factory SubmissionDetail.fromJson(Map<String, dynamic> json) =>
      SubmissionDetail(
        sessionId: J.intOr(json['session_id'] ?? json['id']),
        sessionCode: J.asString(json['session_code']),
        title: J.stringOr(json['title'], 'Phiên đề xuất'),
        content: J.asString(json['content']),
        sourceUrl: J.asString(json['source_url']),
        subjectId: J.asInt(json['subject_id']),
        subjectName: J.asString(json['subject_name']),
        subjectCode: J.asString(json['subject_code']),
        status: SessionStatus.parse(json['status']),
        reviewedBy: J.asString(json['reviewed_by_lecturer']),
        reviewedAt: J.asDate(json['reviewed_at']),
        createdAt: J.asDate(json['created_at']),
        reactCount: J.intOr(json['react_count']),
        commentCount: J.intOr(json['comment_count']),
        questions: J.list(json['questions'], SubmissionQuestion.fromJson),
      );

  @override
  List<Object?> get props => [
    sessionId,
    title,
    content,
    sourceUrl,
    subjectId,
    status,
    reviewedBy,
    reviewedAt,
    questions,
  ];
}

/// Các câu hỏi của một phiên để luyện tập (`GET /sessions/{id}/questions`).
class SessionQuestions extends Equatable {
  final int sessionId;
  final String? sessionCode;
  final String title;
  final String? content;
  final int? subjectId;
  final String? subjectName;
  final String? subjectCode;
  final DateTime? createdAt;
  final int totalQuestions;
  final List<PracticeQuestion> questions;

  const SessionQuestions({
    required this.sessionId,
    this.sessionCode,
    required this.title,
    this.content,
    this.subjectId,
    this.subjectName,
    this.subjectCode,
    this.createdAt,
    this.totalQuestions = 0,
    this.questions = const [],
  });

  factory SessionQuestions.fromJson(Map<String, dynamic> json) {
    final questions = J.list(json['questions'], PracticeQuestion.fromJson);
    return SessionQuestions(
      sessionId: J.intOr(json['session_id'] ?? json['id']),
      sessionCode: J.asString(json['session_code']),
      title: J.stringOr(json['title'], 'Phiên câu hỏi'),
      content: J.asString(json['content']),
      subjectId: J.asInt(json['subject_id']),
      subjectName: J.asString(json['subject_name']),
      subjectCode: J.asString(json['subject_code']),
      createdAt: J.asDate(json['created_at']),
      totalQuestions: J.asInt(json['total_questions']) ?? questions.length,
      questions: questions,
    );
  }

  @override
  List<Object?> get props => [sessionId, title, totalQuestions, questions];
}

/// Kết quả nộp phiên mới (`POST /sessions/propose`).
class ProposeResult extends Equatable {
  final int sessionId;
  final String? sessionCode;
  final int? subjectId;
  final int questionCount;
  final SessionStatus status;
  final DateTime? createdAt;

  const ProposeResult({
    required this.sessionId,
    this.sessionCode,
    this.subjectId,
    this.questionCount = 0,
    this.status = SessionStatus.pending,
    this.createdAt,
  });

  factory ProposeResult.fromJson(Map<String, dynamic> json) => ProposeResult(
    sessionId: J.intOr(json['session_id'] ?? json['id']),
    sessionCode: J.asString(json['session_code']),
    subjectId: J.asInt(json['subject_id']),
    questionCount: J.intOr(json['question_count']),
    status: json['status'] == null
        ? SessionStatus.pending
        : SessionStatus.parse(json['status']),
    createdAt: J.asDate(json['created_at']),
  );

  @override
  List<Object?> get props => [sessionId, subjectId, questionCount, status];
}

/// Một câu hỏi người dùng đang soạn (form tạo / sửa phiên).
///
/// Body tạo mới và body sửa KHÁC nhau: tạo mới gửi `llm_generated`, sửa gửi
/// `source` và `question_id` (null = câu mới thêm vào phiên).
class QuestionDraft extends Equatable {
  final int? questionId;
  final String content;
  final List<String> mediaUrls;
  final List<QuestionOption> options;
  final String? explanation;
  final QuestionSource source;

  /// Độ tự tin của tác giả, 0.0 - 4.0 (xem [RatingLevel])
  final double? confidence;

  const QuestionDraft({
    this.questionId,
    required this.content,
    this.mediaUrls = const [],
    this.options = const [],
    this.explanation,
    this.source = QuestionSource.human,
    this.confidence,
  });

  /// Mở lại câu đã nộp để sửa.
  factory QuestionDraft.fromSubmission(SubmissionQuestion q) => QuestionDraft(
    questionId: q.questionId,
    content: q.content,
    mediaUrls: q.imageUrls,
    options: q.options,
    explanation: q.explanation,
    source: q.source,
    confidence: q.confidence,
  );

  /// `QuestionProposeDto` của `POST /sessions/propose`.
  Map<String, dynamic> toProposeJson() => {
    'content': content.trim(),
    if (mediaUrls.isNotEmpty) 'media_urls': mediaUrls,
    'options': [for (final o in options) o.toJson()],
    'explanation': ?_clean(explanation),
    'llm_generated': source == QuestionSource.llm,
    if (confidence != null) 'confidence': confidence,
  };

  /// `QuestionUpdateDto` của `PUT /sessions/my-submissions/{id}`.
  Map<String, dynamic> toUpdateJson() => {
    'question_id': questionId,
    'content': content.trim(),
    'media_urls': mediaUrls,
    'options': [for (final o in options) o.toJson()],
    'explanation': ?_clean(explanation),
    'source': source.apiValue,
    if (confidence != null) 'confidence': confidence,
  };

  @override
  List<Object?> get props => [
    questionId,
    content,
    mediaUrls,
    options,
    explanation,
    source,
    confidence,
  ];
}

/// Một phiên người dùng đang soạn (form tạo / sửa phiên).
class SessionDraft extends Equatable {
  final int subjectId;
  final String title;
  final String? content;
  final String? sourceUrl;
  final List<QuestionDraft> questions;

  const SessionDraft({
    required this.subjectId,
    required this.title,
    this.content,
    this.sourceUrl,
    this.questions = const [],
  });

  /// Mở lại phiên đã nộp để sửa.
  factory SessionDraft.fromDetail(SubmissionDetail d) => SessionDraft(
    subjectId: d.subjectId ?? 0,
    title: d.title,
    content: d.content,
    sourceUrl: d.sourceUrl,
    questions: [for (final q in d.questions) QuestionDraft.fromSubmission(q)],
  );

  Map<String, dynamic> _base() => {
    'subject_id': subjectId,
    'title': title.trim(),
    'content': ?_clean(content),
    'source_url': ?_clean(sourceUrl),
  };

  /// `ProposeSessionRequest` của `POST /sessions/propose`.
  Map<String, dynamic> toProposeJson() => {
    ..._base(),
    'questions': [for (final q in questions) q.toProposeJson()],
  };

  /// `UpdateSubmissionSessionRequest` của `PUT /sessions/my-submissions/{id}`.
  Map<String, dynamic> toUpdateJson() => {
    ..._base(),
    'questions': [for (final q in questions) q.toUpdateJson()],
  };

  @override
  List<Object?> get props => [subjectId, title, content, sourceUrl, questions];
}
