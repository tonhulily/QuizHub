import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quizhub/data/models/push_notification_payload.dart';

void main() {
  group('PushNotificationPayload.fromRemoteMessage', () {
    test('parse đầy đủ notification và data', () {
      final message = RemoteMessage(
        messageId: 'message-001',
        notification: const RemoteNotification(
          title: 'Lời mời kết bạn',
          body: 'Nguyễn Văn A đã gửi lời mời kết bạn',
        ),
        data: {
          'targetType': 'user',
          'targetId': '123',
          'targetUrl': 'https://snsqb.duckdns.org/users/123',
          'pushType': 'friend_request',
        },
      );

      final payload = PushNotificationPayload.fromRemoteMessage(message);

      expect(payload.title, 'Lời mời kết bạn');
      expect(payload.body, 'Nguyễn Văn A đã gửi lời mời kết bạn');
      expect(payload.targetType, 'USER');
      expect(payload.targetId, 123);
      expect(
        payload.targetUrl,
        'https://snsqb.duckdns.org/users/123',
      );
      expect(payload.pushType, 'FRIEND_REQUEST');
    });

    test('chuyển targetType và pushType thành chữ hoa', () {
      final message = RemoteMessage(
        data: {
          'targetType': 'post',
          'pushType': 'new_comment',
        },
      );

      final payload = PushNotificationPayload.fromRemoteMessage(message);

      expect(payload.targetType, 'POST');
      expect(payload.pushType, 'NEW_COMMENT');
    });

    test('parse targetId dạng số nguyên', () {
      final message = RemoteMessage(
        data: {'targetId': 456},
      );

      final payload = PushNotificationPayload.fromRemoteMessage(message);

      expect(payload.targetId, 456);
    });

    test('targetId không hợp lệ được chuyển thành null', () {
      final message = RemoteMessage(
        data: {'targetId': 'invalid-id'},
      );

      final payload = PushNotificationPayload.fromRemoteMessage(message);

      expect(payload.targetId, isNull);
    });

    test('payload thiếu data vẫn được khởi tạo bình thường', () {
      final message = RemoteMessage();

      final payload = PushNotificationPayload.fromRemoteMessage(message);

      expect(payload.title, isNull);
      expect(payload.body, isNull);
      expect(payload.imageUrl, isNull);
      expect(payload.targetType, isNull);
      expect(payload.targetId, isNull);
      expect(payload.targetUrl, isNull);
      expect(payload.pushType, isNull);
    });

    test('bỏ qua notification khi message chỉ có data', () {
      final message = RemoteMessage(
        data: {
          'targetType': 'QUESTION',
          'targetId': '789',
        },
      );

      final payload = PushNotificationPayload.fromRemoteMessage(message);

      expect(payload.title, isNull);
      expect(payload.body, isNull);
      expect(payload.targetType, 'QUESTION');
      expect(payload.targetId, 789);
    });

    test('ưu tiên imageUrl từ Android notification', () {
      final message = RemoteMessage(
        notification: const RemoteNotification(
          android: AndroidNotification(
            imageUrl: 'https://example.com/image.png',
          ),
        ),
      );

      final payload = PushNotificationPayload.fromRemoteMessage(message);

      expect(payload.imageUrl, 'https://example.com/image.png');
    });

    test('chấp nhận targetId không phải String nếu chuyển được sang String', () {
      final message = RemoteMessage(
        data: {
          'targetId': 1001,
        },
      );

      final payload = PushNotificationPayload.fromRemoteMessage(message);

      expect(payload.targetId, 1001);
    });
  });
}
