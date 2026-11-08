import 'dart:async';

import '../../data/models/post_model.dart';

/// Sự kiện bài viết toàn cục (giống [SessionEvents] nhưng cho nội dung).
///
/// Màn tạo bài viết phát sự kiện đăng; màn sửa phát sự kiện cập nhật để các
/// danh sách đang mở đồng bộ nội dung mà không cần tải lại toàn bộ dữ liệu.
class PostEvents {
  final _published = StreamController<PostModel>.broadcast();
  final _updated = StreamController<PostModel>.broadcast();

  Stream<PostModel> get onPublished => _published.stream;
  Stream<PostModel> get onUpdated => _updated.stream;

  void publish(PostModel post) {
    if (!_published.isClosed) _published.add(post);
  }

  void update(PostModel post) {
    if (!_updated.isClosed) _updated.add(post);
  }

  void dispose() {
    _published.close();
    _updated.close();
  }
}
