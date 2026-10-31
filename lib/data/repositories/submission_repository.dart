import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/json_utils.dart';
import '../models/cursor_page.dart';
import '../models/session_models.dart';

/// Phiên đề xuất câu hỏi CỦA TÔI (Swagger mục 17).
///
/// Một phiên là một bộ câu hỏi trắc nghiệm cho một môn. Chỉ sửa / xoá được
/// khi phiên còn `PENDING` (đã duyệt thì server trả 403), và chỉ đề xuất cho
/// môn đang học (`SubjectRepository.enrolled`).
class SubmissionRepository {
  final ApiClient _api;

  SubmissionRepository(this._api);

  /// `GET /sessions/my-submissions`
  Future<CursorPage<SubmissionSummary>> mySubmissions({
    String? after,
    int limit = AppConfig.defaultPageSize,
    int? subjectId,
    SessionStatus? status,
  }) => _api.get<CursorPage<SubmissionSummary>>(
    ApiEndpoints.mySubmissions,
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

  /// `GET /sessions/my-submissions/{id}` - có đủ đáp án đúng, độ tự tin,
  /// người duyệt.
  Future<SubmissionDetail> detail(int sessionId) => _api.get<SubmissionDetail>(
    ApiEndpoints.mySubmission(sessionId),
    parser: (d) => SubmissionDetail.fromJson(J.asMap(d) ?? const {}),
  );

  /// `POST /sessions/propose` - phiên mới ở trạng thái `PENDING`.
  Future<ProposeResult> propose(SessionDraft draft) => _api.post<ProposeResult>(
    ApiEndpoints.sessionPropose,
    body: draft.toProposeJson(),
    parser: (d) => ProposeResult.fromJson(J.asMap(d) ?? const {}),
  );

  /// `PUT /sessions/my-submissions/{id}` - chỉ khi `PENDING`.
  Future<void> update(int sessionId, SessionDraft draft) => _api.putVoid(
    ApiEndpoints.mySubmission(sessionId),
    body: draft.toUpdateJson(),
  );

  /// `DELETE /sessions/my-submissions/{id}` - xoá cả câu hỏi và ảnh, chỉ khi
  /// `PENDING`.
  Future<void> delete(int sessionId) =>
      _api.deleteVoid(ApiEndpoints.mySubmission(sessionId));
}
