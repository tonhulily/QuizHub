import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/notification_models.dart';

/// Truy cập API danh sách và trạng thái thông báo.
class NotificationRepository {
  final ApiClient _api;

  NotificationRepository(this._api);

  static const int maxPageSize = 50;

  /// GET /notifications
  ///
  /// Cursor được giữ dạng String để tương thích PageLoader/CursorPage hiện tại.
  /// Dio sẽ serialize nó thành query parameter.
  Future<NotificationPageResponse> getNotifications({
    String? after,
    int limit = AppConfig.defaultPageSize,
  }) {
    return _api.get<NotificationPageResponse>(
      ApiEndpoints.notifications,
      query: {'after': after, 'limit': limit.clamp(1, maxPageSize).toInt()},
      parser: NotificationPageResponse.fromJson,
    );
  }

  /// POST /notifications/{id}/read
  Future<MarkNotificationReadResponse> markAsRead(int notificationId) {
    if (notificationId <= 0) {
      throw ArgumentError.value(
        notificationId,
        'notificationId',
        'ID thông báo phải lớn hơn 0',
      );
    }

    return _api.post<MarkNotificationReadResponse>(
      ApiEndpoints.notificationRead(notificationId),
      parser: MarkNotificationReadResponse.fromJson,
    );
  }

  /// POST /notifications/read-all (data trả về object rỗng).
  Future<void> markAllAsRead() =>
      _api.postVoid(ApiEndpoints.notificationsReadAll);
}
