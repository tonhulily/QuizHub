import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/json_utils.dart';
import '../models/comment_model.dart';
import '../models/react_result.dart';

/// Cảm xúc (app chỉ dùng LIKE). Gọi lại cùng loại = gỡ react (toggle).
class ReactionRepository {
  final ApiClient _api;

  ReactionRepository(this._api);

  /// `POST /react`
  Future<ReactResult> toggleLike({
    required TargetType targetType,
    required int targetId,
  }) => _api.post<ReactResult>(
    ApiEndpoints.react,
    body: {
      'target_type': targetType.apiValue,
      'target_id': targetId,
      'reaction_type': 'LIKE',
    },
    parser: (d) => ReactResult.fromJson(J.asMap(d) ?? const {}),
  );
}
