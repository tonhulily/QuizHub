import 'dart:async';

import '../../data/models/post_model.dart';

/// Sự kiện bài viết toàn cục (giống [SessionEvents] nhưng cho nội dung).
///
/// Màn tạo bài viết phát [PostEvents.published]; Bảng tin và Trang cá nhân
/// lắng nghe để chèn bài mới lên đầu mà không cần gọi lại API. Module sau
/// (sửa / xoá / chia sẻ) có thể thêm stream tương tự tại đây.
class PostEvents {
  final _published = StreamController<PostModel>.broadcast();

  Stream<PostModel> get onPublished => _published.stream;

  void publish(PostModel post) {
    if (!_published.isClosed) _published.add(post);
  }

  void dispose() => _published.close();
}
