import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:quizhub/core/firebase/firebase_messaging_service.dart';
import 'package:quizhub/data/models/push_notification_payload.dart';

import '../helpers/fake_firebase_messaging_gateway.dart';

void main() {
  late FakeFirebaseMessagingGateway gateway;
  late List<PushNotificationPayload> openedPayloads;

  RemoteMessage createMessage({
    String? title,
    String? body,
    Map<String, dynamic> data = const {},
  }) {
    return RemoteMessage(
      notification: title == null && body == null
          ? null
          : RemoteNotification(
              title: title,
              body: body,
            ),
      data: data,
    );
  }

  setUp(() {
    gateway = FakeFirebaseMessagingGateway();
    openedPayloads = [];
  });

  tearDown(() async {
    await gateway.close();
  });

  FirebaseMessagingService createService({
    Future<void> Function(PushNotificationPayload)?
        openNotification,
  }) {
    return FirebaseMessagingService(
      messaging: gateway,
      openNotification: openNotification ??
          (payload) async {
            openedPayloads.add(payload);
          },
    );
  }

  group('FirebaseMessagingService.initialize', () {
    test('khởi tạo thành công', () async {
      final service = createService();

      await service.initialize();

      expect(gateway.backgroundHandlerRegistrations, 1);
      expect(gateway.permissionRequests, 1);
      expect(gateway.registerCalls, 1);
      expect(gateway.initialMessageCalls, 1);
    });

    test('không khởi tạo nhiều lần', () async {
      final service = createService();

      await service.initialize();
      await service.initialize();

      expect(gateway.backgroundHandlerRegistrations, 1);
      expect(gateway.permissionRequests, 1);
      expect(gateway.registerCalls, 1);
      expect(gateway.initialMessageCalls, 1);
    });

    test('có thể khởi tạo lại sau khi dispose', () async {
      final service = createService();

      await service.initialize();
      await service.dispose();
      await service.initialize();

      expect(gateway.backgroundHandlerRegistrations, 2);
      expect(gateway.permissionRequests, 2);
      expect(gateway.registerCalls, 2);
    });

    test('không đánh dấu initialized khi register thất bại',
        () async {
      final service = createService();

      gateway.shouldFailRegister = true;

      await expectLater(
        service.initialize(),
        throwsException,
      );

      expect(gateway.registerCalls, 1);

      gateway.shouldFailRegister = false;

      await service.initialize();

      expect(gateway.registerCalls, 2);
    });
  });

  group('FirebaseMessagingService registration', () {
    test('cập nhật currentToken khi nhận registration token',
        () async {
      final service = createService();

      await service.initialize();

      expect(service.currentToken, isNull);

      gateway.registeredController.add('token-001');

      await Future<void>.delayed(Duration.zero);

      expect(service.currentToken, 'token-001');
    });

    test('cập nhật token mới khi token thay đổi', () async {
      final service = createService();

      await service.initialize();

      gateway.registeredController.add('token-001');
      await Future<void>.delayed(Duration.zero);

      gateway.registeredController.add('token-002');
      await Future<void>.delayed(Duration.zero);

      expect(service.currentToken, 'token-002');
    });
  });

  group('FirebaseMessagingService foreground', () {
    test('phát foreground event khi nhận notification',
        () async {
      final service = createService();
      final events = <void>[];

      final subscription = service.foregroundEvents.listen(
        events.add,
      );

      await service.initialize();

      gateway.foregroundController.add(
        createMessage(
          title: 'New notification',
          body: 'You have a new message',
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));

      await subscription.cancel();
    });

    test('phát nhiều event tương ứng với nhiều notification',
        () async {
      final service = createService();
      var eventCount = 0;

      final subscription = service.foregroundEvents.listen(
        (_) => eventCount++,
      );

      await service.initialize();

      gateway.foregroundController.add(createMessage());
      gateway.foregroundController.add(createMessage());
      gateway.foregroundController.add(createMessage());

      await Future<void>.delayed(Duration.zero);

      expect(eventCount, 3);

      await subscription.cancel();
    });

    test('không nhận event sau khi dispose', () async {
      final service = createService();
      var eventCount = 0;

      final subscription = service.foregroundEvents.listen(
        (_) => eventCount++,
      );

      await service.initialize();
      await service.dispose();

      gateway.foregroundController.add(createMessage());

      await Future<void>.delayed(Duration.zero);

      expect(eventCount, 0);

      await subscription.cancel();
    });
  });

  group('FirebaseMessagingService notification tap', () {
    test('giữ initial notification khi navigation chưa sẵn sàng',
        () async {
      gateway.initialMessage = createMessage(
        title: 'Approved',
        data: {
          'targetType': 'QUESTION',
          'targetId': '123',
        },
      );

      final service = createService();

      await service.initialize();

      expect(openedPayloads, isEmpty);

      await service.markNavigationReady();

      expect(openedPayloads, hasLength(1));
      expect(openedPayloads.first.targetType, 'QUESTION');
      expect(openedPayloads.first.targetId, 123);
    });

    test('xử lý notification khi app được mở từ background',
        () async {
      final service = createService();

      await service.initialize();

      gateway.openedController.add(
        createMessage(
          title: 'New comment',
          data: {
            'targetType': 'POST',
            'targetId': '456',
          },
        ),
      );

      await Future<void>.delayed(Duration.zero);

      // Navigation chưa sẵn sàng nên chưa mở.
      expect(openedPayloads, isEmpty);

      await service.markNavigationReady();

      expect(openedPayloads, hasLength(1));
      expect(openedPayloads.first.targetType, 'POST');
      expect(openedPayloads.first.targetId, 456);
    });

    test('không mở notification khi navigation chưa sẵn sàng',
        () async {
      final service = createService();

      await service.initialize();

      gateway.openedController.add(
        createMessage(
          data: {'targetType': 'USER'},
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(openedPayloads, isEmpty);
    });

    test('không mở notification khi navigation đã bị đánh dấu not ready',
        () async {
      final service = createService();

      await service.initialize();
      await service.markNavigationReady();
      service.markNavigationNotReady();

      gateway.openedController.add(
        createMessage(
          data: {'targetType': 'POST'},
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(openedPayloads, isEmpty);
    });

    test('giữ pending notification nếu mở thất bại và cho phép retry',
        () async {
      var shouldFail = true;
      final service = createService(
        openNotification: (payload) async {
          if (shouldFail) {
            throw Exception('Navigation failed');
          }

          openedPayloads.add(payload);
        },
      );

      await service.initialize();

      gateway.openedController.add(
        createMessage(
          data: {
            'targetType': 'QUESTION',
            'targetId': '789',
          },
        ),
      );

      await Future<void>.delayed(Duration.zero);

      await service.markNavigationReady();

      // Lần đầu thất bại.
      expect(openedPayloads, isEmpty);

      shouldFail = false;

      await service.handlePendingNotification();

      expect(openedPayloads, hasLength(1));
      expect(openedPayloads.first.targetId, 789);

      // Pending đã được xóa sau khi xử lý thành công.
      await service.handlePendingNotification();

      expect(openedPayloads, hasLength(1));
    });

    test('không xử lý đồng thời cùng một pending notification',
        () async {
      final completer = Completer<void>();
      var callCount = 0;

      final service = createService(
        openNotification: (payload) async {
          callCount++;
          await completer.future;
        },
      );

      await service.initialize();

      gateway.openedController.add(
        createMessage(
          data: {'targetType': 'POST'},
        ),
      );

      await Future<void>.delayed(Duration.zero);

      final firstCall = service.markNavigationReady();
      final secondCall = service.handlePendingNotification();

      await secondCall;

      expect(callCount, 1);

      completer.complete();
      await firstCall;

      expect(callCount, 1);
    });
  });

  group('FirebaseMessagingService.dispose', () {
    test('hủy các listener khi dispose', () async {
      final service = createService();

      await service.initialize();
      await service.dispose();

      gateway.registeredController.add('token-after-dispose');
      gateway.foregroundController.add(createMessage());

      await Future<void>.delayed(Duration.zero);

      expect(service.currentToken, isNull);
    });
  });
}
