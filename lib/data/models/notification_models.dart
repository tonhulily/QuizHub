import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';
import 'cursor_page.dart';

/// Người thực hiện hành động dẫn tới thông báo.
class NotificationActor extends Equatable {
  final int userId;
  final String fullName;
  final String? avatarUrl;
  final String? frameUrl;

  const NotificationActor({
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    this.frameUrl,
  });

  factory NotificationActor.fromJson(Map<String, dynamic> json) =>
      NotificationActor(
        userId: J.intOr(json['user_id']),
        fullName: J.stringOr(json['full_name'], 'Người dùng'),
        avatarUrl: J.asString(json['avatar_url']),
        frameUrl: J.asString(json['frame_url']),
      );

  @override
  List<Object?> get props => [userId, fullName, avatarUrl, frameUrl];
}

/// Đích điều hướng của thông báo. Giữ type dạng String vì backend
/// chưa công bố đầy đủ danh sách target type.
class NotificationTarget extends Equatable {
  final String type;
  final int? targetId;
  final String? url;

  const NotificationTarget({required this.type, this.targetId, this.url});

  factory NotificationTarget.fromJson(Map<String, dynamic> json) =>
      NotificationTarget(
        type: J.stringOr(json['type'], 'UNKNOWN'),
        targetId: J.asInt(json['target_id']),
        url: J.asString(json['url']),
      );

  @override
  List<Object?> get props => [type, targetId, url];
}

/// Một thông báo trong danh sách của người dùng.
class NotificationModel extends Equatable {
  final int notificationId;
  final String type;
  final String title;
  final String body;
  final String? iconUrl;
  final DateTime? readAt;
  final DateTime? createdAt;
  final NotificationTarget? target;
  final NotificationActor? actor;

  /// Metadata thay đổi theo loại thông báo nên giữ kiểu Map linh hoạt.
  final Map<String, dynamic>? metadata;

  const NotificationModel({
    required this.notificationId,
    required this.type,
    required this.title,
    required this.body,
    this.iconUrl,
    this.readAt,
    this.createdAt,
    this.target,
    this.actor,
    this.metadata,
  });

  bool get isRead => readAt != null;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final targetJson = J.asMap(json['target']);
    final actorJson = J.asMap(json['actor']);
    final metadataJson = J.asMap(json['metadata']);

    return NotificationModel(
      notificationId: J.intOr(json['notification_id']),
      type: J.stringOr(json['type'], 'UNKNOWN'),
      title: J.stringOr(json['title']),
      body: J.stringOr(json['body']),
      iconUrl: J.asString(json['icon_url']),
      readAt: J.asDate(json['read_at']),
      createdAt: J.asDate(json['created_at']),
      target: targetJson == null
          ? null
          : NotificationTarget.fromJson(targetJson),
      actor: actorJson == null
          ? null
          : NotificationActor.fromJson(actorJson),
      metadata: metadataJson == null
          ? null
          : Map<String, dynamic>.unmodifiable(metadataJson),
    );
  }

  /// Tạo bản sao đã đọc sau khi API xác nhận thành công.
  NotificationModel markRead(DateTime readTime) => NotificationModel(
        notificationId: notificationId,
        type: type,
        title: title,
        body: body,
        iconUrl: iconUrl,
        readAt: readAt ?? readTime,
        createdAt: createdAt,
        target: target,
        actor: actor,
        metadata: metadata,
      );

  @override
  List<Object?> get props => [
        notificationId,
        type,
        title,
        body,
        iconUrl,
        readAt,
        createdAt,
        target,
        actor,
        metadata,
      ];
}

/// Response GET /notifications. unreadCount được tách khỏi CursorPage
/// để không phải sửa model phân trang dùng chung của ứng dụng.
class NotificationPageResponse extends Equatable {
  final CursorPage<NotificationModel> page;
  final int unreadCount;

  const NotificationPageResponse({
    required this.page,
    this.unreadCount = 0,
  });

  factory NotificationPageResponse.fromJson(dynamic data) {
    final map = J.asMap(data) ?? const <String, dynamic>{};
    return NotificationPageResponse(
      page: CursorPage<NotificationModel>.fromJson(
        map,
        NotificationModel.fromJson,
      ),
      unreadCount: J.intOr(map['unread_count']),
    );
  }

  @override
  List<Object?> get props => [page, unreadCount];
}

/// Response POST /notifications/{id}/read.
class MarkNotificationReadResponse extends Equatable {
  final int notificationId;
  final DateTime? readAt;
  final int unreadCount;
  final bool read;

  const MarkNotificationReadResponse({
    required this.notificationId,
    this.readAt,
    this.unreadCount = 0,
    this.read = true,
  });

  factory MarkNotificationReadResponse.fromJson(dynamic data) {
    final map = J.asMap(data) ?? const <String, dynamic>{};
    return MarkNotificationReadResponse(
      notificationId: J.intOr(map['notification_id']),
      readAt: J.asDate(map['read_at']),
      unreadCount: J.intOr(map['unread_count']),
      read: J.asBool(map['read'], true),
    );
  }

  @override
  List<Object?> get props => [notificationId, readAt, unreadCount, read];
}
