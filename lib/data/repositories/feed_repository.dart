import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/json_utils.dart';
import '../../core/storage/local_storage.dart';
import '../models/cursor_page.dart';
import '../models/feed_item.dart';

/// Bảng tin trang chủ: `GET /activity-feeds`.
///
/// Trang đầu được cache cục bộ để lần mở app sau hiển thị tức thì
/// (yêu cầu phi chức năng: cache trang chủ).
class FeedRepository {
  final ApiClient _api;
  final LocalStorage _storage;

  FeedRepository(this._api, this._storage);

  /// Trang đầu từ cache (null nếu chưa có).
  CursorPage<FeedItem>? get cachedFirstPage {
    final raw = _storage.homeFeedCache;
    if (raw == null) return null;
    try {
      return _withoutDeleted(CursorPage.fromJson(raw, FeedItem.fromJson));
    } catch (_) {
      return null;
    }
  }

  Future<CursorPage<FeedItem>> getFeed({
    String? after,
    int limit = AppConfig.defaultPageSize,
  }) async {
    Map<String, dynamic>? raw;
    final page = await _api.get<CursorPage<FeedItem>>(
      ApiEndpoints.activityFeeds,
      query: {'after': after, 'limit': limit},
      parser: (d) {
        if (d is Map<String, dynamic>) raw = d;
        return CursorPage.fromJson(d, FeedItem.fromJson);
      },
    );
    if (after == null && raw != null) {
      await _storage.setHomeFeedCache(raw!);
    }
    await _dropGhostsOfMine(page);
    return _withoutDeleted(page);
  }

  /// Bài của CHÍNH MÌNH mà server báo không còn (404) -> ghi nhớ là đã xoá.
  ///
  /// Backend xoá mềm bài nhưng dòng hoạt động vẫn còn, nên bảng tin có thể hiện
  /// lại bài đã xoá. Chỉ kiểm tra bài của mình (thường rất ít) để không tốn
  /// request cho bài của người khác. Lỗi mạng thì bỏ qua và giữ nguyên bài.
  Future<void> _dropGhostsOfMine(CursorPage<FeedItem> page) async {
    final myId = J.asInt(_storage.cachedUser?['user_id']);
    if (myId == null) return;
    final deleted = _storage.deletedPostIds;
    final mine = page.items.where(
      (i) =>
          i.postId != null &&
          i.actor?.userId == myId &&
          !deleted.contains(i.postId),
    );
    await Future.wait(
      mine.map((i) async {
        try {
          await _api.get<void>(ApiEndpoints.post(i.postId!), parser: (_) {});
        } on ApiException catch (e) {
          if (e.type == ApiErrorType.notFound) {
            await _storage.addDeletedPostId(i.postId!);
          }
        }
      }),
    );
  }

  /// Ẩn các bài đã xoá (server có thể vẫn trả bản chụp cũ trong dòng hoạt động).
  CursorPage<FeedItem> _withoutDeleted(CursorPage<FeedItem> page) {
    final deleted = _storage.deletedPostIds;
    if (deleted.isEmpty) return page;
    return page.filtered((i) => !deleted.contains(i.postId));
  }
}
