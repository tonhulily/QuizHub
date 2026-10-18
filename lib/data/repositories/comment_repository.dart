import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/json_utils.dart';
import '../models/comment_model.dart';
import '../models/cursor_page.dart';

/// Bình luận: `/comments`.
///
/// Nghiệp vụ: chủ bài viết KHÔNG xoá được bình luận của người khác; chủ bình
/// luận KHÔNG sửa được bình luận (nên không có hàm update ở đây).
class CommentRepository {
  final ApiClient _api;

  CommentRepository(this._api);

  /// `GET /comments` - danh sách bình luận gốc của [target], hoặc danh sách
  /// phản hồi nếu truyền [parentCommentId].
  Future<CursorPage<CommentModel>> list({
    required TargetType targetType,
    required int targetId,
    int? parentCommentId,
    bool newestFirst = true,
    String? after,
    int limit = 20,
  }) => _api.get<CursorPage<CommentModel>>(
    ApiEndpoints.comments,
    query: {
      'target_type': targetType.apiValue,
      'target_id': targetId,
      'parent_comment_id': parentCommentId,
      'sort': newestFirst ? 'newest' : 'oldest',
      'after': after,
      'limit': limit,
    },
    parser: (d) => CursorPage.fromJson(d, CommentModel.fromJson),
  );

  /// `POST /comments`
  Future<CommentModel> create({
    required TargetType targetType,
    required int targetId,
    required String content,
    int? parentCommentId,
    String? mediaUrl,
  }) => _api.post<CommentModel>(
    ApiEndpoints.comments,
    body: {
      'target_type': targetType.apiValue,
      'target_id': targetId,
      'content': content,
      'parent_comment_id': ?parentCommentId,
      'media_url': ?mediaUrl,
    },
    parser: (d) => CommentModel.fromJson(J.asMap(d) ?? const {}),
  );

  /// `DELETE /comments/{id}` (chỉ người tạo)
  Future<void> delete(int commentId) =>
      _api.deleteVoid(ApiEndpoints.comment(commentId));
}
