import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/local_storage.dart';
import '../../core/utils/json_utils.dart';
import '../models/cursor_page.dart';
import '../models/media_item.dart';
import '../models/post_model.dart';

/// Bài viết: `/posts`, `/posts/me`, `/users/{id}/posts`, `/video-posts`.
class PostRepository {
  final ApiClient _api;
  final LocalStorage _storage;

  PostRepository(this._api, this._storage);

  /// `POST /posts`
  Future<PostModel> create({
    required String content,
    List<MediaItem> media = const [],
    PostVisibility visibility = PostVisibility.public,
    PostType postType = PostType.socialPost,
    int? subjectId,
  }) => _api.post<PostModel>(
    ApiEndpoints.posts,
    body: {
      'content': content,
      'media_urls': media.map((m) => m.toJson()).toList(),
      'visibility': visibility.apiValue,
      'post_type': postType.apiValue,
      'subject_id': ?subjectId,
    },
    parser: (d) => PostModel.fromJson(J.asMap(d) ?? const {}),
  );

  /// `GET /posts/{id}`
  Future<PostModel> getById(int id) => _api.get<PostModel>(
    ApiEndpoints.post(id),
    parser: (d) => PostModel.fromJson(J.asMap(d) ?? const {}),
  );

  /// `PUT /posts/{id}` (chỉ tác giả)
  Future<void> update(
    int id, {
    String? content,
    List<MediaItem>? media,
    PostVisibility? visibility,
  }) => _api.put<void>(
    ApiEndpoints.post(id),
    body: {
      'content': ?content,
      if (media != null) 'media_urls': media.map((m) => m.toJson()).toList(),
      'visibility': ?visibility?.apiValue,
    },
    parser: (_) {},
  );

  /// `DELETE /posts/{id}` (tác giả hoặc admin).
  ///
  /// Trả về `true` nếu vừa xoá được, `false` nếu bài đã không còn trên server
  /// (404) - coi như đã xoá xong để UI gỡ bài "ma" khỏi danh sách. Id được nhớ
  /// lại để các danh sách sau không hiện lại bài này.
  Future<bool> delete(int id) async {
    try {
      await _api.deleteVoid(ApiEndpoints.post(id));
      await _storage.addDeletedPostId(id);
      return true;
    } on ApiException catch (e) {
      if (e.type == ApiErrorType.notFound) {
        await _storage.addDeletedPostId(id);
        return false;
      }
      rethrow;
    }
  }

  CursorPage<PostModel> _withoutDeleted(CursorPage<PostModel> page) {
    final deleted = _storage.deletedPostIds;
    if (deleted.isEmpty) return page;
    return page.filtered((p) => !deleted.contains(p.postId));
  }

  /// `GET /posts/me`
  Future<CursorPage<PostModel>> myPosts({
    String? after,
    int limit = AppConfig.defaultPageSize,
  }) => _api.get<CursorPage<PostModel>>(
    ApiEndpoints.myPosts,
    query: {'after': after, 'limit': limit},
    parser: (d) => _withoutDeleted(CursorPage.fromJson(d, PostModel.fromJson)),
  );

  /// `GET /users/{id}/posts`
  Future<CursorPage<PostModel>> userPosts(
    int userId, {
    String? after,
    int limit = AppConfig.defaultPageSize,
  }) => _api.get<CursorPage<PostModel>>(
    ApiEndpoints.userPosts(userId),
    query: {'after': after, 'limit': limit},
    parser: (d) => _withoutDeleted(CursorPage.fromJson(d, PostModel.fromJson)),
  );
}
