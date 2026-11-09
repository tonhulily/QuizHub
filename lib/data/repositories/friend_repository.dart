import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/services/blocked_users.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/json_utils.dart';
import '../models/cursor_page.dart';
import '../models/social_models.dart';

/// Quan hệ xã hội: bạn bè, lời mời, theo dõi, chặn.
///
/// Quy tắc của backend: chỉ kết bạn được với người CÙNG vai trò (sinh viên với
/// sinh viên, giảng viên với giảng viên); theo dõi thì không phân biệt. Gửi lời
/// mời cho người đã gửi lời mời cho mình sẽ tự động thành bạn. Chặn ai đó sẽ tự
/// hủy bạn bè và theo dõi hai chiều.
class FriendRepository {
  final ApiClient _api;
  final BlockedUsers? _blocks;

  FriendRepository(this._api, {BlockedUsers? blocks}) : _blocks = blocks;
  bool _visible(int userId) => !(_blocks?.contains(userId) ?? false);

  // ---------------- Danh sách ----------------

  /// `GET /friendships`
  Future<CursorPage<FriendModel>> friends({
    String? after,
    int limit = AppConfig.defaultPageSize,
  }) => _api.get<CursorPage<FriendModel>>(
    ApiEndpoints.friendships,
    query: {'after': after, 'limit': limit},
    parser: (d) => CursorPage.fromJson(
      d,
      FriendModel.fromJson,
    ).filtered((u) => _visible(u.userId)),
  );

  /// `GET /friendships/requests/received`
  Future<CursorPage<FriendRequestModel>> receivedRequests({
    String? after,
    int limit = AppConfig.defaultPageSize,
  }) => _api.get<CursorPage<FriendRequestModel>>(
    ApiEndpoints.friendRequestsReceived,
    query: {'after': after, 'limit': limit},
    parser: (d) => CursorPage.fromJson(
      d,
      FriendRequestModel.fromReceivedJson,
    ).filtered((r) => _visible(r.user.userId)),
  );

  /// `GET /friendships/requests/sent`
  Future<CursorPage<FriendRequestModel>> sentRequests({
    String? after,
    int limit = AppConfig.defaultPageSize,
  }) => _api.get<CursorPage<FriendRequestModel>>(
    ApiEndpoints.friendRequestsSent,
    query: {'after': after, 'limit': limit},
    parser: (d) => CursorPage.fromJson(
      d,
      FriendRequestModel.fromSentJson,
    ).filtered((r) => _visible(r.user.userId)),
  );

  /// `GET /follows/followers` - danh sách người theo dõi tài khoản hiện tại.
  Future<CursorPage<RelationshipUserModel>> followers({
    String? after,
    int limit = AppConfig.defaultPageSize,
  }) => _api.get<CursorPage<RelationshipUserModel>>(
    ApiEndpoints.followers,
    query: {'after': after, 'limit': limit},
    parser: (d) => CursorPage.fromJson(
      d,
      RelationshipUserModel.fromJson,
    ).filtered((u) => _visible(u.userId)),
  );

  /// `GET /follows/following` - danh sách tài khoản hiện tại đang theo dõi.
  Future<CursorPage<RelationshipUserModel>> following({
    String? after,
    int limit = AppConfig.defaultPageSize,
  }) => _api.get<CursorPage<RelationshipUserModel>>(
    ApiEndpoints.following,
    query: {'after': after, 'limit': limit},
    parser: (d) => CursorPage.fromJson(
      d,
      RelationshipUserModel.fromJson,
    ).filtered((u) => _visible(u.userId)),
  );

  /// `GET /blocks` - danh sách tài khoản đã chặn.
  Future<CursorPage<RelationshipUserModel>> blockedUsers({
    String? after,
    int limit = AppConfig.defaultPageSize,
  }) => _api.get<CursorPage<RelationshipUserModel>>(
    ApiEndpoints.blocks,
    query: {'after': after, 'limit': limit},
    parser: (d) => CursorPage.fromJson(d, RelationshipUserModel.fromJson),
  );

  /// `GET /blocks` - chỉ lấy id (dùng để loại khỏi gợi ý).
  Future<Set<int>> blockedIds({int limit = 50}) async {
    final owner = _blocks?.ownerId;
    final revision = _blocks?.revision;
    final ids = <int>{};
    final cursors = <String>{};
    String? after;
    while (true) {
      final page = await blockedUsers(after: after, limit: limit);
      ids.addAll(page.items.map((u) => u.userId).where((id) => id > 0));
      if (!page.hasNext) break;
      after = page.after;
      if (after == null || !cursors.add(after)) {
        throw const ApiException(
          type: ApiErrorType.server,
          message: 'Không thể tải đủ danh sách đã chặn.',
        );
      }
    }
    if (_blocks?.revision == revision) {
      await _blocks?.replace(ids, forUser: owner);
    }
    return ids;
  }

  // ---------------- Hành động ----------------

  /// `POST /friendships/request` -> `PENDING`, hoặc `ACCEPTED` nếu người kia đã
  /// gửi lời mời cho mình trước đó (server tự chấp nhận).
  Future<String> sendRequest(int userId) {
    _blocks?.requireVisible(userId);
    return _api.post<String>(
      ApiEndpoints.friendRequest,
      body: {'addressee_id': userId},
      parser: (d) => J.stringOr(J.asMap(d)?['status'], 'PENDING'),
    );
  }

  /// `POST /friendships/accept`
  Future<void> accept(int requesterId) {
    _blocks?.requireVisible(requesterId);
    return _api.postVoid(
      ApiEndpoints.friendAccept,
      body: {'requester_id': requesterId},
    );
  }

  /// `POST /friendships/decline`
  Future<void> decline(int requesterId) => _api.postVoid(
    ApiEndpoints.friendDecline,
    body: {'requester_id': requesterId},
  );

  /// `DELETE /friendships/{id}`
  Future<void> unfriend(int friendId) =>
      _api.deleteVoid(ApiEndpoints.unfriend(friendId));

  /// `POST /follows/{id}`
  Future<void> follow(int userId) {
    _blocks?.requireVisible(userId);
    return _api.postVoid(ApiEndpoints.follow(userId));
  }

  /// `DELETE /follows/{id}`
  Future<void> unfollow(int userId) =>
      _api.deleteVoid(ApiEndpoints.follow(userId));

  /// `POST /blocks/{id}` (tự hủy bạn bè + theo dõi hai chiều)
  Future<void> block(int userId) async {
    final owner = _blocks?.ownerId;
    await _api.postVoid(ApiEndpoints.block(userId));
    await _blocks?.add(userId, forUser: owner);
  }

  /// `DELETE /blocks/{id}`
  Future<void> unblock(int userId) async {
    final owner = _blocks?.ownerId;
    await _api.deleteVoid(ApiEndpoints.block(userId));
    await _blocks?.remove(userId, forUser: owner);
  }
}
