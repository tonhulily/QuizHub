import 'dart:async';
import 'dart:convert';

import '../network/api_exception.dart';
import '../storage/local_storage.dart';
import '../utils/json_utils.dart';

/// Danh sách chặn dùng chung cho FE, tách theo tài khoản và môi trường chạy.
class BlockedUsers {
  final LocalStorage _storage;
  final String scope;
  final _changed = StreamController<void>.broadcast();
  int? _owner;
  Set<int> _ids = {};
  int _revision = 0;

  BlockedUsers(this._storage, {required this.scope});

  Stream<void> get onChanged => _changed.stream;
  int? get ownerId => J.asInt(_storage.cachedUser?['user_id']);
  int get revision {
    ids;
    return _revision;
  }

  String _key(int userId) => 'blocked_users_${scope}_$userId';

  Set<int> get ids {
    final owner = ownerId;
    if (owner != _owner) {
      _owner = owner;
      _revision++;
      _ids = {};
      final raw = owner == null ? null : _storage.getString(_key(owner));
      if (raw != null) {
        try {
          final rows = jsonDecode(raw);
          if (rows is List) {
            _ids = rows
                .map(J.asInt)
                .whereType<int>()
                .where((id) => id > 0)
                .toSet();
          }
        } on FormatException {
          // Không dùng dữ liệu chặn cục bộ hỏng.
        }
      }
    }
    return Set.unmodifiable(_ids);
  }

  bool contains(int? userId) => userId != null && ids.contains(userId);

  void requireVisible(int userId) {
    if (contains(userId)) throw unavailable;
  }

  static const unavailable = ApiException(
    type: ApiErrorType.forbidden,
    code: 'USER_BLOCKED',
    statusCode: 403,
    message: 'Nội dung không khả dụng khi tài khoản đã bị chặn.',
  );

  Future<void> add(int id, {required int? forUser}) async {
    if (forUser == null || forUser != ownerId) return;
    await replace({...ids, id}, forUser: forUser);
  }

  Future<void> remove(int id, {required int? forUser}) async {
    if (forUser == null || forUser != ownerId) return;
    await replace({...ids}..remove(id), forUser: forUser);
  }

  Future<void> replace(Set<int> next, {required int? forUser}) async {
    if (forUser == null || forUser != ownerId) return;
    final before = ids;
    next = next.where((id) => id > 0 && id != forUser).toSet();
    if (before.length == next.length && before.containsAll(next)) return;
    _ids = {...next};
    _revision++;
    // Cập nhật các màn đang mở ngay, kể cả nếu ghi bộ nhớ cục bộ bị lỗi.
    if (!_changed.isClosed) _changed.add(null);
    try {
      await _storage.setString(_key(forUser), jsonEncode(next.toList()));
    } catch (_) {
      // API đã xác nhận thao tác. Giữ chặn trong phiên này; lần sau đồng bộ lại.
    }
  }

  void dispose() => _changed.close();
}
