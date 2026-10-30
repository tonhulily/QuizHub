import '../../core/network/api_exception.dart';
import '../models/profile_model.dart';
import 'user_repository.dart';

/// Tra tên / ảnh của người dùng theo id (`GET /users/{id}`), có cache.
///
/// Dùng cho danh sách chỉ có `user_id` (vd đánh giá câu hỏi). Nhiều dòng cùng
/// một người chỉ gọi API một lần; gọi lỗi thì trả null (màn hình hiện lại
/// "Người dùng #id") và lần sau thử lại.
class UserDirectory {
  final UserRepository _users;
  final Map<int, Future<ProfileModel?>> _cache = {};

  UserDirectory(this._users);

  Future<ProfileModel?> lookup(int userId) =>
      _cache.putIfAbsent(userId, () => _fetch(userId));

  Future<ProfileModel?> _fetch(int userId) async {
    try {
      return await _users.getUser(userId);
    } on ApiException {
      _cache.remove(userId);
      return null;
    }
  }
}
