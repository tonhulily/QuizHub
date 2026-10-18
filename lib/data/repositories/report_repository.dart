import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';

enum ReportTarget {
  post,
  comment,
  user;

  String get apiValue => name.toUpperCase();
}

enum ViolationType {
  spam('SPAM', 'Spam / quảng cáo'),
  harassment('HARASSMENT', 'Quấy rối, bắt nạt'),
  hateStatement('HATE_STATEMENT', 'Ngôn từ thù ghét'),
  other('OTHER', 'Lý do khác');

  final String apiValue;
  final String label;
  const ViolationType(this.apiValue, this.label);
}

/// Báo cáo vi phạm: `POST /report`.
class ReportRepository {
  final ApiClient _api;

  ReportRepository(this._api);

  Future<void> report({
    required ReportTarget targetType,
    required int targetId,
    required ViolationType violation,
    String? description,
    List<String> evidenceUrls = const [],
  }) => _api.postVoid(
    ApiEndpoints.report,
    body: {
      'target_type': targetType.apiValue,
      'target_id': targetId,
      'violation_type': violation.apiValue,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (evidenceUrls.isNotEmpty) 'evidence_urls': evidenceUrls,
    },
  );
}
