import '../../core/storage/local_storage.dart';
import '../models/comment_model.dart';

class LikeStateStore {
  final LocalStorage _storage;

  LikeStateStore(this._storage);

  String _key(int userId, TargetType type, int targetId) =>
      '${LocalStorage.likeKeyPrefix}${userId}_${type.apiValue}_$targetId';

  /// null nếu chưa từng bấm trên máy này.
  bool? get(int userId, TargetType type, int targetId) =>
      _storage.getBool(_key(userId, type, targetId));

  Future<void> set(int userId, TargetType type, int targetId, bool reacted) =>
      _storage.setBool(_key(userId, type, targetId), reacted);
}