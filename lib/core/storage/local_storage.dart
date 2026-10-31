import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Lưu trữ cục bộ dạng key-value (không nhạy cảm).
///
/// Mọi key khai báo tập trung ở đây để tránh trùng lặp / gõ sai.
class LocalStorage {
  static const _kDeviceId = 'device_id';
  static const _kUserCache = 'cached_user';
  static const _kHomeFeedCache = 'cached_home_feed';
  static const _kDeletedPosts = 'deleted_post_ids';
  static const _maxDeletedPosts = 500;

  final SharedPreferences _prefs;

  LocalStorage(this._prefs);

  // ---- Device ----
  String? get deviceId => _prefs.getString(_kDeviceId);
  Future<void> setDeviceId(String id) => _prefs.setString(_kDeviceId, id);

  // ---- Cached current user (hiển thị tức thì khi mở app) ----
  Map<String, dynamic>? get cachedUser => _readJson(_kUserCache);
  Future<void> setCachedUser(Map<String, dynamic> json) =>
      _prefs.setString(_kUserCache, jsonEncode(json));
  Future<void> clearCachedUser() => _prefs.remove(_kUserCache);

  // ---- Cache trang chủ (yêu cầu phi chức năng: load nhanh từ cache) ----
  Map<String, dynamic>? get homeFeedCache => _readJson(_kHomeFeedCache);
  Future<void> setHomeFeedCache(Map<String, dynamic> json) =>
      _prefs.setString(_kHomeFeedCache, jsonEncode(json));
  Future<void> clearHomeFeedCache() => _prefs.remove(_kHomeFeedCache);

  // ---- Bài viết đã xoá (ẩn khỏi mọi danh sách trên máy này) ----
  //
  // Backend xoá mềm bài viết nhưng dòng hoạt động (activity feed) có thể vẫn
  // trả về bản chụp cũ của bài. Nhớ lại id đã xoá để không hiện lại bài "ma".
  Set<int> get deletedPostIds =>
      (_prefs.getStringList(_kDeletedPosts) ?? const <String>[])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();

  Future<void> addDeletedPostId(int id) async {
    final list = List<String>.of(
      _prefs.getStringList(_kDeletedPosts) ?? const <String>[],
    );
    if (list.contains('$id')) return;
    list.add('$id');
    // Chỉ giữ các id gần nhất để không phình bộ nhớ
    final trimmed = list.length > _maxDeletedPosts
        ? list.sublist(list.length - _maxDeletedPosts)
        : list;
    await _prefs.setStringList(_kDeletedPosts, trimmed);
  }

  // ---- Generic helpers cho module khác dùng ----
  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
  bool? getBool(String key) => _prefs.getBool(key);
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);
  Future<void> remove(String key) => _prefs.remove(key);

  Future<void> removeKeysStartingWith(String prefix) async {
    for (final k
        in _prefs.getKeys().where((k) => k.startsWith(prefix)).toList()) {
      await _prefs.remove(k);
    }
  }

  static const likeKeyPrefix = 'like_';

  /// Xoá dữ liệu gắn với user khi đăng xuất (giữ lại device_id).
  Future<void> clearUserData() async {
    await clearCachedUser();
    await clearHomeFeedCache();
    await removeKeysStartingWith(likeKeyPrefix);
  }

  Map<String, dynamic>? _readJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
