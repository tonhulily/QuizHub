import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/json_utils.dart';
import '../models/cursor_page.dart';
import '../models/exam_models.dart';

/// Đề thi (Swagger mục 20). TOÀN BỘ chỉ dành cho giảng viên: sinh viên gọi
/// sẽ nhận 403, nên UI phải ẩn nhánh này với sinh viên.
class ExamRepository {
  final ApiClient _api;

  ExamRepository(this._api);

  /// Backend giới hạn tối đa 20 đề mỗi trang.
  static const int maxPageSize = 20;

  /// `GET /lecturer/course-classes/my-classes` - lớp đang dạy trong học kỳ
  /// hiện tại; sinh đề bắt buộc chọn ít nhất một lớp.
  Future<List<CourseClassModel>> myClasses() =>
      _api.get<List<CourseClassModel>>(
        ApiEndpoints.lecturerMyClasses,
        parser: (d) => J.list(d, CourseClassModel.fromJson),
      );

  /// `POST /exams/generate` - bốc ngẫu nhiên câu `APPROVED` theo môn, số
  /// lượng, tỉ lệ độ khó, trọng số chủ đề. 400 nếu ngân hàng môn đó trống.
  Future<ExamDetail> generate(GenerateExamInput input) => _api.post<ExamDetail>(
    ApiEndpoints.examGenerate,
    body: input.toJson(),
    parser: (d) => ExamDetail.fromJson(J.asMap(d) ?? const {}),
  );

  /// `GET /exams/my-exams`
  Future<CursorPage<ExamSummary>> myExams({
    String? after,
    int limit = 10,
    int? subjectId,
  }) => _api.get<CursorPage<ExamSummary>>(
    ApiEndpoints.myExams,
    query: {
      'after': after,
      'limit': limit > maxPageSize ? maxPageSize : limit,
      'subject_id': subjectId,
    },
    parser: (d) => CursorPage.fromJson(d, ExamSummary.fromJson),
  );

  /// `GET /exams/{id}`
  Future<ExamDetail> detail(int examId) => _api.get<ExamDetail>(
    ApiEndpoints.exam(examId),
    parser: (d) => ExamDetail.fromJson(J.asMap(d) ?? const {}),
  );

  /// `GET /exams/{id}/export` - server dựng file rồi trả link tải có hạn
  /// (`ExportResult.expiresAt`): mở ngay, đừng lưu link.
  Future<ExportResult> exportFile(
    int examId, {
    ExportFormat format = ExportFormat.pdf,
    bool includeAnswerKey = false,
    String paperSize = 'A4',
  }) => _api.get<ExportResult>(
    ApiEndpoints.examExport(examId),
    query: {
      'format': format.apiValue,
      'include_answer_key': includeAnswerKey,
      'paper_size': paperSize,
    },
    parser: (d) => ExportResult.fromJson(J.asMap(d) ?? const {}),
  );
}
