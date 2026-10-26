import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/json_utils.dart';
import '../models/ai_models.dart';

/// AI tinh chỉnh câu hỏi (Swagger mục 24). Hai bước tách rời: [refine] chỉ
/// trả bản gợi ý, [apply] mới ghi vào câu hỏi. Nhờ vậy người dùng luôn được
/// xem và quyết định trước khi dữ liệu thay đổi.
///
/// Chỉ dùng cho câu ĐÃ có id (đã nộp). Apply dành cho giảng viên / người
/// kiểm duyệt; sinh viên có được refine hay không cần kiểm tra với backend.
class AiRepository {
  final ApiClient _api;

  AiRepository(this._api);

  /// Backend giới hạn độ dài chỉ thị.
  static const int maxPromptLength = 1000;

  /// `POST /questions/{id}/ai-refine`
  ///
  /// 403 `CONTENT_VIOLATES_POLICY`: chỉ thị bị chặn (nghi prompt injection),
  /// báo người dùng sửa chỉ thị, không tự thử lại.
  Future<AiRefineResult> refine(
    int questionId, {
    required String prompt,
    String? chatSessionId,
  }) => _api.post<AiRefineResult>(
    ApiEndpoints.questionAiRefine(questionId),
    body: {
      'prompt': prompt.trim(),
      'chat_session_id': ?chatSessionId,
    },
    parser: (d) => AiRefineResult.fromJson(J.asMap(d) ?? const {}),
  );

  /// `POST /questions/{id}/ai-apply` - [approve] = true ghi đè câu hỏi gốc
  /// bằng bản gợi ý, false bỏ bản gợi ý.
  Future<AiApplyResult> apply(
    int questionId, {
    required int editLogId,
    required bool approve,
  }) => _api.post<AiApplyResult>(
    ApiEndpoints.questionAiApply(questionId),
    body: {'edit_log_id': editLogId, 'approve': approve},
    parser: (d) => AiApplyResult.fromJson(J.asMap(d) ?? const {}),
  );
}
