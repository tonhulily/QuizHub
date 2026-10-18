import 'dart:async';

/// Sự kiện quan hệ xã hội toàn cục (kết bạn, hủy bạn, chặn...).
///
/// Trang cá nhân của người khác phát [notifyChanged] sau mỗi thao tác; tab Bạn
/// bè lắng nghe để tải lại danh sách mà không phải kéo để làm mới.
class SocialEvents {
  final _changed = StreamController<void>.broadcast();

  Stream<void> get onChanged => _changed.stream;

  void notifyChanged() {
    if (!_changed.isClosed) _changed.add(null);
  }

  void dispose() => _changed.close();
}
