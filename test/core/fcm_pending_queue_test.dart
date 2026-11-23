import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/firebase/firebase_messaging_service.dart';
import 'package:quizhub/data/models/push_notification_payload.dart';

import '../helpers/fake_firebase_messaging_gateway.dart';

void main() {
  test(
    'opens a second tapped notification after first navigation completes',
    () async {
      final gateway = FakeFirebaseMessagingGateway();
      final firstNavigation = Completer<void>();
      final openedIds = <int?>[];
      final service = FirebaseMessagingService(
        messaging: gateway,
        openNotification: (PushNotificationPayload payload) async {
          openedIds.add(payload.targetId);
          if (payload.targetId == 1) await firstNavigation.future;
        },
      );
      addTearDown(service.dispose);
      addTearDown(gateway.close);

      await service.initialize();
      await service.markNavigationReady();

      gateway.openedController.add(
        RemoteMessage(data: {'targetType': 'POST', 'targetId': '1'}),
      );
      await Future<void>.delayed(Duration.zero);
      expect(openedIds, [1]);

      gateway.openedController.add(
        RemoteMessage(data: {'targetType': 'POST', 'targetId': '2'}),
      );
      await Future<void>.delayed(Duration.zero);
      firstNavigation.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(openedIds, [1, 2]);
    },
  );
}
