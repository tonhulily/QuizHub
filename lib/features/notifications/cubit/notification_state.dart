import 'package:equatable/equatable.dart';

import '../../../core/network/api_exception.dart';

/// State cho các thao tác ngoài danh sách phân trang:
/// unread count, trạng thái đang đánh dấu đã đọc và lỗi thao tác.
class NotificationState extends Equatable {
  final int unreadCount;
  final Set<int> busyNotificationIds;
  final bool markingAllAsRead;
  final ApiException? actionError;

  const NotificationState({
    this.unreadCount = 0,
    this.busyNotificationIds = const {},
    this.markingAllAsRead = false,
    this.actionError,
  });

  NotificationState copyWith({
    int? unreadCount,
    Set<int>? busyNotificationIds,
    bool? markingAllAsRead,
    ApiException? actionError,
    bool clearActionError = false,
  }) {
    return NotificationState(
      unreadCount: unreadCount ?? this.unreadCount,
      busyNotificationIds:
          busyNotificationIds ?? this.busyNotificationIds,
      markingAllAsRead: markingAllAsRead ?? this.markingAllAsRead,
      actionError: clearActionError ? null : (actionError ?? this.actionError),
    );
  }

  @override
  List<Object?> get props => [
        unreadCount,
        busyNotificationIds,
        markingAllAsRead,
        actionError,
      ];
}
