import '../../core/config/app_config.dart';
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

  FriendRepository(this._api);

  // ---------------- Danh sách ----------------

  /// `GET /friendships`
  Future<CursorPage<FriendModel>> friends({
    String? after,
    int limit = AppConfig.defaultPageSize,
  }) => _api.get<CursorPage<FriendModel>>(
    ApiEndpoints.friendships,
    query: {'after': after, 'limit': limit},
    parser: (d) => CursorPage.fromJson(d, FriendModel.fromJson),
  );

  /// `GET /friendships/requests/received`
  Future<CursorPage<FriendRequestModel>> receivedRequests({
    String? after,
    int limit = AppConfig.defaultPageSize,
  }) => _api.get<CursorPage<FriendRequestModel>>(
    ApiEndpoints.friendRequestsReceived,
    query: {'after': after, 'limit': limit},
    parser: (d) => CursorPage.fromJson(d, FriendRequestModel.fromReceivedJson),
  );

  /// `GET /friendships/requests/sent`
  Future<CursorPage<FriendRequestModel>> sentRequests({
    String? after,
    int limit = AppConfig.defaultPageSize,
  }) => _api.get<CursorPage<FriendRequestModel>>(
    ApiEndpoints.friendRequestsSent,
    query: {'after': after, 'limit': limit},
    parser: (d) => CursorPage.fromJson(d, FriendRequestModel.fromSentJson),
  );

  /// `GET /blocks` - chỉ lấy id (dùng để loại khỏi gợi ý).
  Future<Set<int>> blockedIds({int limit = 50}) => _api.get<Set<int>>(
    ApiEndpoints.blocks,
    query: {'limit': limit},
    parser: (d) => {
      for (final raw in J.asList(J.asMap(d)?['items']))
        if (J.asMap(raw) case final m?) J.intOr(m['user_id']),
    },
  );

  // ---------------- Hành động ----------------

  /// `POST /friendships/request` -> `PENDING`, hoặc `ACCEPTED` nếu người kia đã
  /// gửi lời mời cho mình trước đó (server tự chấp nhận).
  Future<String> sendRequest(int userId) => _api.post<String>(
    ApiEndpoints.friendRequest,
    body: {'addressee_id': userId},
    parser: (d) => J.stringOr(J.asMap(d)?['status'], 'PENDING'),
  );

  /// `POST /friendships/accept`
  Future<void> accept(int requesterId) => _api.postVoid(
    ApiEndpoints.friendAccept,
    body: {'requester_id': requesterId},
  );

  /// `POST /friendships/decline`
  Future<void> decline(int requesterId) => _api.postVoid(
    ApiEndpoints.friendDecline,
    body: {'requester_id': requesterId},
  );

  /// `DELETE /friendships/{id}`
  Future<void> unfriend(int friendId) =>
      _api.deleteVoid(ApiEndpoints.unfriend(friendId));

  /// `POST /follows/{id}`
  Future<void> follow(int userId) => _api.postVoid(ApiEndpoints.follow(userId));

  /// `DELETE /follows/{id}`
  Future<void> unfollow(int userId) =>
      _api.deleteVoid(ApiEndpoints.follow(userId));

  /// `POST /blocks/{id}` (tự hủy bạn bè + theo dõi hai chiều)
  Future<void> block(int userId) => _api.postVoid(ApiEndpoints.block(userId));

  /// `DELETE /blocks/{id}`
  Future<void> unblock(int userId) =>
      _api.deleteVoid(ApiEndpoints.block(userId));
}
