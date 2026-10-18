import 'dart:math';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/auth_session.dart';
import '../models/social_models.dart';
import 'friend_repository.dart';

/// Tìm người dùng và gợi ý kết bạn.
///
/// Backend KHÔNG có endpoint gợi ý kết bạn và KHÔNG tìm được bằng email đầy đủ
/// (`/search` chỉ khớp tên và mã SV/GV). Vì vậy:
/// - Gợi ý = lấy một đoạn ngẫu nhiên trong danh sách người dùng của hệ thống
///   (`/search?type=USER` với từ khoá rỗng), loại những người đã là bạn / đã
///   gửi / đã nhận lời mời / đã chặn / khác vai trò.
/// - Tìm bằng email = suy ra mã SV/GV từ email rồi lọc đúng email ở phía app.
class UserSearchRepository {
  /// Số bản ghi tối đa mỗi trang mà `/search` cho phép.
  static const int maxPageSize = 50;

  final ApiClient _api;
  final FriendRepository _friends;

  UserSearchRepository(this._api, this._friends);

  /// `GET /search?type=USER`. [query] rỗng = liệt kê toàn bộ người dùng.
  Future<UserSearchPage> searchUsers(
    String query, {
    int? after,
    int limit = 20,
  }) => _api.get<UserSearchPage>(
    ApiEndpoints.search,
    query: {
      'type': 'USER',
      'query': query.trim(),
      'after': after,
      'limit': limit.clamp(1, maxPageSize),
    },
    parser: UserSearchPage.fromJson,
  );

  // ---------------- Tìm bằng email ----------------

  static final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool looksLikeEmail(String input) => _emailRe.hasMatch(input.trim());

  /// Email của trường có dạng `Ten.XY235184@sis.hust.edu.vn` trong đó
  /// `235184` ứng với mã SV `20235184` (thêm tiền tố `20`).
  static String? codeFromEmail(String email) {
    final local = email.trim().split('@').first;
    final digits = RegExp(r'(\d+)$').firstMatch(local)?.group(1);
    if (digits == null || digits.length < 5) return null;
    return '20$digits';
  }

  /// Tìm đúng 1 người theo email. Trả về null nếu không có.
  Future<UserSearchResult?> findByEmail(String email) async {
    final wanted = email.trim().toLowerCase();
    if (!looksLikeEmail(wanted)) return null;

    final queries = <String>[
      ?codeFromEmail(wanted),
      // Dự phòng: phần tên trước dấu chấm, vd "tung" trong "Tung.VN236058"
      wanted.split('@').first.split('.').first,
    ];
    for (final q in queries) {
      if (q.isEmpty) continue;
      final page = await searchUsers(q, limit: maxPageSize);
      for (final u in page.items) {
        if ((u.email ?? '').toLowerCase() == wanted) return u;
      }
    }
    return null;
  }

  // ---------------- Gợi ý kết bạn ----------------

  /// Gợi ý tối đa [count] người chưa có quan hệ với mình.
  Future<List<UserSearchResult>> suggestions({
    required int myUserId,
    required UserRole myRole,
    int count = 20,
    Random? random,

    /// Id đã có quan hệ (bạn / lời mời) nếu người gọi đã biết; truyền vào để
    /// khỏi gọi lại các danh sách đó.
    Set<int>? alreadyRelated,
  }) async {
    final rnd = random ?? Random();

    // 1) Những người đã có quan hệ (trang đầu của mỗi danh sách là đủ dùng)
    final blockedF = _friends.blockedIds(limit: maxPageSize);
    final exclude = <int>{myUserId};
    if (alreadyRelated != null) {
      exclude.addAll(alreadyRelated);
    } else {
      final friendsF = _friends.friends(limit: maxPageSize);
      final sentF = _friends.sentRequests(limit: maxPageSize);
      final receivedF = _friends.receivedRequests(limit: maxPageSize);
      exclude
        ..addAll((await friendsF).items.map((f) => f.userId))
        ..addAll((await sentF).items.map((r) => r.user.userId))
        ..addAll((await receivedF).items.map((r) => r.user.userId));
    }
    exclude.addAll(await blockedF);

    // 2) Lấy tổng số người dùng rồi chọn một đoạn ngẫu nhiên
    final head = await searchUsers('', limit: 1);
    if (head.totalHits == 0) return const [];
    final window = min(maxPageSize, head.totalHits);
    final offset = head.totalHits <= window
        ? 0
        : rnd.nextInt(head.totalHits - window + 1);
    final page = await searchUsers('', after: offset, limit: window);

    // 3) Loại người không hợp lệ rồi xáo trộn
    final candidates =
        page.items
            .where((u) => !exclude.contains(u.userId) && u.role == myRole)
            .toList()
          ..shuffle(rnd);
    return candidates.take(count).toList();
  }
}
