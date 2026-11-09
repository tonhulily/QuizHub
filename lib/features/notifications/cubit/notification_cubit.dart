import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/paged_cubit.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/models/cursor_page.dart';
import '../../../data/models/notification_models.dart';
import '../../../data/repositories/notification_repository.dart';
import 'notification_state.dart';

/// Điều phối danh sách thông báo phân trang và các thao tác đọc.
///
/// [notificationsCubit] được đưa trực tiếp vào PagedListView để tái sử dụng
/// cơ chế refresh/load-more dùng chung của ứng dụng.
/// Cubit này chỉ quản lý unread count và trạng thái các thao tác mutation.
class NotificationCubit extends Cubit<NotificationState> {
  final NotificationRepository _repository;

  late final PagedCubit<NotificationModel> notificationsCubit;

  NotificationCubit(this._repository) : super(const NotificationState()) {
    notificationsCubit = PagedCubit<NotificationModel>(_loadPage);
  }

  Future<CursorPage<NotificationModel>> _loadPage(String? after) async {
    final response = await _repository.getNotifications(after: after);

    // unread_count được backend trả kèm từng trang; luôn lấy giá trị mới nhất.
    if (!isClosed) {
      emit(state.copyWith(
        unreadCount: response.unreadCount,
        clearActionError: true,
      ));
    }

    return response.page;
  }

  /// Tải trang đầu tiên.
  Future<void> load() => notificationsCubit.load();

  /// Kéo xuống để tải lại trang đầu.
  Future<void> refresh() => notificationsCubit.refresh();

  /// Đánh dấu một thông báo đã đọc.
  ///
  /// Trả về null nếu thành công; trả ApiException để UI tự hiển thị lỗi,
  /// thống nhất với convention của FriendsCubit.
  Future<ApiException?> markAsRead(NotificationModel notification) async {
    final id = notification.notificationId;

    if (notification.isRead ||
        state.markingAllAsRead ||
        state.busyNotificationIds.contains(id)) {
      return null;
    }

    _setBusy(id, true);

    try {
      final response = await _repository.markAsRead(id);
      if (isClosed) return null;

      final readAt = response.readAt ?? DateTime.now();
      notificationsCubit.replaceWhere(
        (item) => item.notificationId == id,
        notification.markRead(readAt),
      );

      emit(state.copyWith(
        unreadCount: response.unreadCount,
        clearActionError: true,
      ));
      return null;
    } on ApiException catch (e) {
      if (!isClosed) emit(state.copyWith(actionError: e));
      return e;
    } finally {
      if (!isClosed) _setBusy(id, false);
    }
  }

  /// Đánh dấu tất cả thông báo đã đọc.
  ///
  /// Backend trả data rỗng nên sau khi request thành công, cập nhật trạng thái
  /// các item hiện có ngay trên client và đặt unread count về 0.
  Future<ApiException?> markAllAsRead() async {
    if (state.markingAllAsRead || state.busyNotificationIds.isNotEmpty) {
      return null;
    }

    emit(state.copyWith(
      markingAllAsRead: true,
      clearActionError: true,
    ));

    try {
      await _repository.markAllAsRead();
      if (isClosed) return null;

      final readAt = DateTime.now();
      notificationsCubit.mapItems(
        (item) => item.isRead ? item : item.markRead(readAt),
      );

      emit(state.copyWith(
        unreadCount: 0,
        markingAllAsRead: false,
      ));
      return null;
    } on ApiException catch (e) {
      if (!isClosed) {
        emit(state.copyWith(
          markingAllAsRead: false,
          actionError: e,
        ));
      }
      return e;
    }
  }

  void _setBusy(int id, bool busy) {
    final ids = Set<int>.from(state.busyNotificationIds);
    if (busy) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    emit(state.copyWith(busyNotificationIds: ids));
  }

  @override
  Future<void> close() async {
    await notificationsCubit.close();
    return super.close();
  }
}
