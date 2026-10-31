import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/json_utils.dart';
import '../models/cursor_page.dart';
import '../models/question_models.dart';
import '../models/session_models.dart';

/// Duyệt ngân hàng câu hỏi và luyện tập (Swagger mục 19 + tìm kiếm).
///
/// Backend CHƯA có API liệt kê phiên theo môn, cũng không có
/// `GET /questions/{id}`: duyệt bằng tìm kiếm / phiên của một người, rồi lấy
/// câu hỏi theo phiên (xem docs/qbank/API_CONTRACT.md mục 6).
class QuestionBankRepository {
  final ApiClient _api;

  QuestionBankRepository(this._api);

  /// `GET /search?type=SESSION` - phân trang offset (`after` là vị trí).
  Future<CursorPage<SubmissionSummary>> searchSessions(
    String query, {
    String? after,
    int limit = AppConfig.defaultPageSize,
  }) => _api.get<CursorPage<SubmissionSummary>>(
    ApiEndpoints.search,
    query: {
      'query': query.trim(),
      'type': 'SESSION',
      'after': after,
      'limit': limit,
    },
    parser: (d) {
      final map = J.asMap(d) ?? const <String, dynamic>{};
      final pagination =
          J.asMap(map['pagination']) ?? const <String, dynamic>{};
      return CursorPage<SubmissionSummary>(
        items: [
          // Bỏ qua kết quả loại khác nếu backend vẫn trả lẫn
          for (final raw in J.asList(map['items']))
            if (J.asMap(J.asMap(raw)?['session']) case final s?)
              SubmissionSummary.fromJson(s),
        ],
        after: J.asString(pagination['after']),
        hasNext: J.asBool(pagination['has_next']),
      );
    },
  );

  /// `GET /search?type=QUESTION` - tìm từng câu hỏi (phân trang offset).
  Future<CursorPage<QuestionHit>> searchQuestions(
    String query, {
    String? after,
    int limit = AppConfig.defaultPageSize,
  }) => _api.get<CursorPage<QuestionHit>>(
    ApiEndpoints.search,
    query: {
      'query': query.trim(),
      'type': 'QUESTION',
      'after': after,
      'limit': limit,
    },
    parser: (d) {
      final map = J.asMap(d) ?? const <String, dynamic>{};
      final pagination =
          J.asMap(map['pagination']) ?? const <String, dynamic>{};
      return CursorPage<QuestionHit>(
        items: [
          for (final raw in J.asList(map['items']))
            if (J.asMap(J.asMap(raw)?['question']) case final q?)
              QuestionHit.fromJson(q),
        ],
        after: J.asString(pagination['after']),
        hasNext: J.asBool(pagination['has_next']),
      );
    },
  );

  /// `GET /users/{id}/sessions` - xem người khác thì chỉ có phiên `RESOLVED`;
  /// lọc `status` chỉ có tác dụng khi xem chính mình.
  Future<CursorPage<SubmissionSummary>> sessionsOfUser(
    int userId, {
    String? after,
    int limit = AppConfig.defaultPageSize,
    int? subjectId,
    SessionStatus? status,
  }) => _api.get<CursorPage<SubmissionSummary>>(
    ApiEndpoints.userSessions(userId),
    query: {
      'after': after,
      'limit': limit,
      'subject_id': subjectId,
      'status': status == null || status == SessionStatus.unknown
          ? null
          : status.apiValue,
    },
    parser: SubmissionSummary.pageFromJson,
  );

  /// `GET /sessions/{id}/questions` - câu chưa trả lời bị ẩn đáp án và lời
  /// giải. 403 nếu phiên chưa duyệt mà mình không phải tác giả.
  Future<SessionQuestions> sessionQuestions(int sessionId) =>
      _api.get<SessionQuestions>(
        ApiEndpoints.sessionQuestions(sessionId),
        parser: (d) => SessionQuestions.fromJson(J.asMap(d) ?? const {}),
      );

  /// `POST /questions/{id}/answer` - mỗi câu chỉ trả lời MỘT lần (lần sau
  /// 409). Truyền [questionUpdatedAt] = `PracticeQuestion.updatedAtRaw` để
  /// server báo 412 nếu câu đã bị sửa từ lúc tải về.
  Future<AnswerResult> answer(
    int questionId,
    List<String> selectedKeys, {
    String? questionUpdatedAt,
  }) => _api.post<AnswerResult>(
    ApiEndpoints.questionAnswer(questionId),
    body: {
      'selected_options': selectedKeys,
      'question_updated_at': ?questionUpdatedAt,
    },
    parser: (d) => AnswerResult.fromJson(J.asMap(d) ?? const {}),
  );

  /// `POST /questions/{id}/rate` - [rating] từ 0 đến 4 (`RatingLevel`);
  /// [isError] = true thì server tự coi điểm là 0.
  Future<RateResult> rate(
    int questionId, {
    required int rating,
    bool isError = false,
    String? comment,
  }) {
    assert(rating >= 0 && rating <= 4, 'rating phải trong khoảng 0-4');
    final note = comment?.trim();
    return _api.post<RateResult>(
      ApiEndpoints.questionRate(questionId),
      body: {
        'rating': isError ? 0 : rating,
        'is_error': isError,
        if (note != null && note.isNotEmpty) 'comment': note,
      },
      parser: (d) => RateResult.fromJson(J.asMap(d) ?? const {}),
    );
  }

  /// `GET /questions/{id}/ratings`
  Future<CursorPage<RatingItem>> ratings(
    int questionId, {
    String? after,
    int limit = AppConfig.defaultPageSize,
  }) => _api.get<CursorPage<RatingItem>>(
    ApiEndpoints.questionRatings(questionId),
    query: {'after': after, 'limit': limit},
    parser: (d) => CursorPage.fromJson(d, RatingItem.fromJson),
  );

  /// `GET /questions/{id}/statistics`
  Future<QuestionStatistics> statistics(int questionId) =>
      _api.get<QuestionStatistics>(
        ApiEndpoints.questionStatistics(questionId),
        parser: (d) => QuestionStatistics.fromJson(J.asMap(d) ?? const {}),
      );
}
