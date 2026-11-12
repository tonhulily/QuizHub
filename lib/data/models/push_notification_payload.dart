import 'package:firebase_messaging/firebase_messaging.dart';

class PushNotificationPayload {
  final String? title;
  final String? body;
  final String? imageUrl;

  final String? targetType;
  final int? targetId;
  final String? targetUrl;
  final String? pushType;

  const PushNotificationPayload({
    this.title,
    this.body,
    this.imageUrl,
    this.targetType,
    this.targetId,
    this.targetUrl,
    this.pushType,
  });

  factory PushNotificationPayload.fromRemoteMessage(RemoteMessage message) {
    final data = message.data;

    return PushNotificationPayload(
      title: message.notification?.title,
      body: message.notification?.body,
      imageUrl:
          message.notification?.android?.imageUrl ??
          message.notification?.apple?.imageUrl,
      targetType: data['targetType']?.toString().toUpperCase(),
      targetId: int.tryParse(data['targetId']?.toString() ?? ''),
      targetUrl: data['targetUrl']?.toString(),
      pushType: data['pushType']?.toString().toUpperCase(),
    );
  }
}
