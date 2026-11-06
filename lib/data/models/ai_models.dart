import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';
import 'question_models.dart';

/// Một vi phạm logic mà bước kiểm định ảo giác (Btprop) tìm thấy.
class AiViolation extends Equatable {
  /// vd CONTRADICTION
  final String type;
  final String? statement;
  final String? detail;

  /// LOW, MEDIUM, HIGH, CRITICAL
  final String? severity;

  const AiViolation({
    required this.type,
    this.statement,
    this.detail,
    this.severity,
  });

  factory AiViolation.fromJson(Map<String, dynamic> json) => AiViolation(
    type: J.stringOr(json['type'], 'UNKNOWN'),
    statement: J.asString(json['node_statement']),
    detail: J.asString(json['detail']),
    severity: J.asString(json['severity']),
  );

  @override
  List<Object?> get props => [type, statement, detail, severity];
}

/// Bản gợi ý của AI (`POST /questions/{id}/ai-refine`). Chưa ghi gì vào câu
/// hỏi: phải gọi apply với [editLogId] thì mới áp dụng.
class AiRefineResult extends Equatable {
  final int editLogId;
  final String content;
  final List<QuestionOption> options;
  final String? explanation;

  /// Có giá trị khi AI từ chối yêu cầu (vi phạm chính sách)
  final String? refusalReason;
  final bool isHallucinated;

  /// Điểm tin cậy của bản gợi ý, 0.0 - 1.0
  final double? confidenceScore;
  final List<AiViolation> violations;
  final String? model;
  final int? tokensUsed;
  final int? processingMs;

  const AiRefineResult({
    required this.editLogId,
    required this.content,
    this.options = const [],
    this.explanation,
    this.refusalReason,
    this.isHallucinated = false,
    this.confidenceScore,
    this.violations = const [],
    this.model,
    this.tokensUsed,
    this.processingMs,
  });

  bool get refused => refusalReason != null;

  factory AiRefineResult.fromJson(Map<String, dynamic> json) {
    final suggested =
        J.asMap(json['suggested_question']) ?? const <String, dynamic>{};
    final audit =
        J.asMap(json['hallucination_audit']) ?? const <String, dynamic>{};
    final meta = J.asMap(json['ai_metadata']) ?? const <String, dynamic>{};
    final refusal = J.asString(suggested['refusal_reason']);
    return AiRefineResult(
      editLogId: J.intOr(json['edit_log_id']),
      content: J.stringOr(suggested['content']),
      options: J.list(suggested['options'], QuestionOption.fromJson),
      explanation: J.asString(suggested['explanation']),
      // Ví dụ trong Swagger là chuỗi "null": coi như không từ chối
      refusalReason: refusal == null || refusal.toLowerCase() == 'null'
          ? null
          : refusal,
      isHallucinated: J.asBool(audit['is_hallucinated']),
      confidenceScore: J.asDouble(audit['confidence_score']),
      violations: J.list(audit['violations'], AiViolation.fromJson),
      model: J.asString(meta['model']),
      tokensUsed: J.asInt(meta['tokens_used']),
      processingMs: J.asInt(meta['processing_time_ms']),
    );
  }

  @override
  List<Object?> get props => [
    editLogId,
    content,
    options,
    explanation,
    refusalReason,
    isHallucinated,
    confidenceScore,
    violations,
  ];
}

/// Kết quả áp dụng / bỏ bản gợi ý (`POST /questions/{id}/ai-apply`).
class AiApplyResult extends Equatable {
  final int questionId;

  /// APPLIED hoặc DISCARDED
  final String status;
  final double? confidenceScore;
  final bool hallucination;

  const AiApplyResult({
    required this.questionId,
    required this.status,
    this.confidenceScore,
    this.hallucination = false,
  });

  bool get applied => status.toUpperCase() == 'APPLIED';

  factory AiApplyResult.fromJson(Map<String, dynamic> json) => AiApplyResult(
    questionId: J.intOr(json['question_id']),
    status: J.stringOr(json['status']),
    confidenceScore: J.asDouble(json['confidence_score']),
    hallucination: J.asBool(json['hallucination']),
  );

  @override
  List<Object?> get props => [
    questionId,
    status,
    confidenceScore,
    hallucination,
  ];
}
