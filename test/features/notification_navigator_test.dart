import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quizhub/core/router/app_routes.dart';
import 'package:quizhub/data/models/chat_models.dart';
import 'package:quizhub/data/models/notification_models.dart';
import 'package:quizhub/data/models/push_notification_payload.dart';
import 'package:quizhub/features/notifications/navigation/notification_navigator.dart';

void main() {
  group('NotificationNavigator.open', () {
    testWidgets('uses a valid internal URL before notification fallback', (
      tester,
    ) async {
      final h = await _pumpHarness(tester);
      await _tapOpen(
        tester,
        h,
        _notification(
          type: 'FRIEND_REQUEST',
          target: const NotificationTarget(
            type: 'USER',
            targetId: 10,
            url: 'https://snsqb.duckdns.org/posts/42',
          ),
        ),
      );

      expect(h.routes.last.name, AppRoutes.postDetail);
      expect(h.routes.last.arguments, 42);
      await _popAndExpectResult(tester, h, true);
    });

    testWidgets('accepts relative internal URL', (tester) async {
      final h = await _pumpHarness(tester);
      await _tapOpen(
        tester,
        h,
        _notification(
          type: 'UNKNOWN',
          target: const NotificationTarget(
            type: 'UNKNOWN',
            url: '/users/23',
          ),
        ),
      );

      expect(h.routes.last.name, AppRoutes.userProfile);
      expect(h.routes.last.arguments, 23);
      await _popAndExpectResult(tester, h, true);
    });

    testWidgets('rejects an external URL and uses safe target fallback', (
      tester,
    ) async {
      final h = await _pumpHarness(tester);
      await _tapOpen(
        tester,
        h,
        _notification(
          type: 'NEW_COMMENT',
          target: const NotificationTarget(
            type: 'POST',
            targetId: 17,
            url: 'https://evil.example/posts/999',
          ),
        ),
      );

      expect(h.routes.last.name, AppRoutes.postDetail);
      expect(h.routes.last.arguments, 17);
      await _popAndExpectResult(tester, h, true);
    });

    testWidgets('rejects an untrusted scheme even with an allowed host', (
      tester,
    ) async {
      final h = await _pumpHarness(tester);
      await _tapOpen(
        tester,
        h,
        _notification(
          type: 'NEW_COMMENT',
          target: const NotificationTarget(
            type: 'POST',
            targetId: 17,
            url: 'javascript://snsqb.duckdns.org/posts/999',
          ),
        ),
      );

      expect(h.routes.last.name, AppRoutes.postDetail);
      expect(h.routes.last.arguments, 17);
      await _popAndExpectResult(tester, h, true);
    });

    testWidgets('maps sessions URL with questionId to global search', (
      tester,
    ) async {
      final h = await _pumpHarness(tester);
      await _tapOpen(
        tester,
        h,
        _notification(
          type: 'UNKNOWN',
          target: const NotificationTarget(
            type: 'UNKNOWN',
            url: '/sessions?questionId=81',
          ),
        ),
      );

      expect(h.routes.last.name, AppRoutes.searchGlobal);
      expect(h.routes.last.arguments, '81');
      await _popAndExpectResult(tester, h, true);
    });

    testWidgets('maps notification types to their expected routes', (
      tester,
    ) async {
      final cases = <({String type, String route, Object? args})>[
        (type: 'FRIEND_REQUEST', route: AppRoutes.userProfile, args: 20),
        (type: 'NEW_COMMENT', route: AppRoutes.postDetail, args: 30),
        (type: 'LEADERBOARD_HONOR', route: AppRoutes.postDetail, args: 30),
        (type: 'QUESTION_APPROVED', route: AppRoutes.qbankSubmission, args: 40),
        (type: 'GAME5_SEMESTER_RECAP', route: AppRoutes.userProfile, args: 50),
      ];

      for (final c in cases) {
        final h = await _pumpHarness(tester);
        final actor = c.type == 'FRIEND_REQUEST'
            ? const NotificationActor(userId: 20, fullName: 'Actor')
            : null;
        await _tapOpen(
          tester,
          h,
          _notification(
            type: c.type,
            target: NotificationTarget(type: 'USER', targetId: c.args as int),
            actor: actor,
          ),
        );
        expect(h.routes.last.name, c.route, reason: c.type);
        expect(h.routes.last.arguments, c.args, reason: c.type);
        await _popAndExpectResult(tester, h, true);
      }
    });

    testWidgets('friend request prefers actor id over target id', (
      tester,
    ) async {
      final h = await _pumpHarness(tester);
      await _tapOpen(
        tester,
        h,
        _notification(
          type: 'FRIEND_REQUEST',
          target: const NotificationTarget(type: 'USER', targetId: 10),
          actor: const NotificationActor(userId: 22, fullName: 'Actor'),
        ),
      );

      expect(h.routes.last.name, AppRoutes.userProfile);
      expect(h.routes.last.arguments, 22);
      await _popAndExpectResult(tester, h, true);
    });

    testWidgets('question error penalty opens my submissions', (tester) async {
      final h = await _pumpHarness(tester);
      await _tapOpen(
        tester,
        h,
        _notification(
          type: 'QUESTION_ERROR_PENALTY',
          target: const NotificationTarget(type: 'QUESTION', targetId: 90),
        ),
      );

      expect(h.routes.last.name, AppRoutes.qbankMySubmissions);
      expect(h.routes.last.arguments, isNull);
      await _popAndExpectResult(tester, h, true);
    });

    testWidgets('generic target types map to their expected routes', (
      tester,
    ) async {
      final cases = <({String type, String route, bool hasId})>[
        (type: 'POST', route: AppRoutes.postDetail, hasId: true),
        (type: 'SESSION', route: AppRoutes.qbankSubmission, hasId: true),
        (type: 'QUESTION', route: AppRoutes.qbankMySubmissions, hasId: false),
        (type: 'USER', route: AppRoutes.userProfile, hasId: true),
        (type: 'CONVERSATION', route: AppRoutes.chatDetail, hasId: true),
      ];

      for (final c in cases) {
        final h = await _pumpHarness(tester);
        await _tapOpen(
          tester,
          h,
          _notification(
            type: 'SOME_NEW_NOTIFICATION',
            target: NotificationTarget(type: c.type, targetId: 61),
          ),
        );

        expect(h.routes.last.name, c.route, reason: c.type);
        if (c.type == 'CONVERSATION') {
          final argument = h.routes.last.arguments;
          expect(argument, isA<ChatTarget>());
          expect(argument, isA<ChatTarget>());
        } else if (c.hasId) {
          expect(h.routes.last.arguments, 61, reason: c.type);
        } else {
          expect(h.routes.last.arguments, isNull, reason: c.type);
        }
        await _popAndExpectResult(tester, h, true);
      }
    });

    testWidgets('returns false and shows a message for unsupported badge', (
      tester,
    ) async {
      final h = await _pumpHarness(tester);
      await _tapOpen(
        tester,
        h,
        _notification(
          type: 'EARNED_BADGE',
          target: const NotificationTarget(type: 'BADGE', targetId: 7),
        ),
      );

      expect(h.routes, isEmpty);
      expect(await h.pending, isFalse);
      expect(find.text('Mục Huy hiệu chưa được triển khai.'), findsOneWidget);
    });

    testWidgets('returns false for missing or invalid required id', (
      tester,
    ) async {
      final h = await _pumpHarness(tester);
      await _tapOpen(
        tester,
        h,
        _notification(
          type: 'NEW_COMMENT',
          target: const NotificationTarget(type: 'POST', targetId: 0),
        ),
      );

      expect(h.routes, isEmpty);
      expect(await h.pending, isFalse);
      expect(find.text('Chưa thể mở nội dung của thông báo này.'), findsOneWidget);
    });
  });

  group('NotificationNavigator.openPush', () {
    testWidgets('uses a valid target URL before target type', (tester) async {
      final h = await _pumpHarness(tester);
      await _tapOpenPush(
        tester,
        h,
        const PushNotificationPayload(
          targetType: 'USER',
          targetId: 10,
          targetUrl: 'https://localhost/posts/72',
        ),
      );

      expect(h.routes.last.name, AppRoutes.postDetail);
      expect(h.routes.last.arguments, 72);
      await _popAndExpectResult(tester, h, true);
    });

    testWidgets('maps push target types to routes', (tester) async {
      final cases = <({String type, String route})>[
        (type: 'POST', route: AppRoutes.postDetail),
        (type: 'SESSION', route: AppRoutes.qbankSubmission),
        (type: 'QUESTION', route: AppRoutes.qbankMySubmissions),
        (type: 'USER', route: AppRoutes.userProfile),
        (type: 'CONVERSATION', route: AppRoutes.chatDetail),
      ];

      for (final c in cases) {
        final h = await _pumpHarness(tester);
        await _tapOpenPush(
          tester,
          h,
          PushNotificationPayload(targetType: c.type, targetId: 88),
        );
        expect(h.routes.last.name, c.route, reason: c.type);
        if (c.type == 'CONVERSATION') {
          expect(h.routes.last.arguments, isA<ChatTarget>());
        } else if (c.type == 'QUESTION') {
          expect(h.routes.last.arguments, isNull);
        } else {
          expect(h.routes.last.arguments, 88, reason: c.type);
        }
        await _popAndExpectResult(tester, h, true);
      }
    });

    testWidgets('rejects invalid push target and unsupported badge', (
      tester,
    ) async {
      final h = await _pumpHarness(tester);
      await _tapOpenPush(
        tester,
        h,
        const PushNotificationPayload(targetType: 'POST', targetId: -1),
      );
      expect(h.routes, isEmpty);
      expect(await h.pending, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      final h2 = await _pumpHarness(tester);
      await _tapOpenPush(
        tester,
        h2,
        const PushNotificationPayload(targetType: 'BADGE', targetId: 5),
      );
      expect(h2.routes, isEmpty);
      expect(await h2.pending, isFalse);
      expect(find.text('Mục Huy hiệu chưa được triển khai.'), findsOneWidget);
    });

    testWidgets('rejects external URL and falls back to safe target type', (
      tester,
    ) async {
      final h = await _pumpHarness(tester);
      await _tapOpenPush(
        tester,
        h,
        const PushNotificationPayload(
          targetType: 'USER',
          targetId: 12,
          targetUrl: 'https://attacker.example/users/999',
        ),
      );

      expect(h.routes.last.name, AppRoutes.userProfile);
      expect(h.routes.last.arguments, 12);
      await _popAndExpectResult(tester, h, true);
    });
  });
}

NotificationModel _notification({
  required String type,
  NotificationTarget? target,
  NotificationActor? actor,
}) => NotificationModel(
  notificationId: 1,
  type: type,
  title: 'Title',
  body: 'Body',
  target: target,
  actor: actor,
);

class _Harness {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final List<RouteSettings> routes = [];
  BuildContext? homeContext;
  Future<bool>? pending;
}

Future<_Harness> _pumpHarness(WidgetTester tester) async {
  final h = _Harness();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: h.navigatorKey,
      scaffoldMessengerKey: h.messengerKey,
      home: Builder(
        builder: (context) {
          h.homeContext = context;
          return const Scaffold(body: Text('Home'));
        },
      ),
      onGenerateRoute: (settings) {
        h.routes.add(settings);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('Destination')),
        );
      },
    ),
  );
  return h;
}

Future<void> _tapOpen(
  WidgetTester tester,
  _Harness h,
  NotificationModel notification,
) async {
  // Replace the harness button callback with the requested notification.
  h.pending = NotificationNavigator.open(h.homeContext!, notification);
  await tester.pump();
}

Future<void> _tapOpenPush(
  WidgetTester tester,
  _Harness h,
  PushNotificationPayload payload,
) async {
  h.pending = NotificationNavigator.openPush(h.homeContext!, payload);
  await tester.pump();
}

Future<void> _popAndExpectResult(
  WidgetTester tester,
  _Harness h,
  bool expected,
) async {
  await tester.pumpAndSettle();
  h.navigatorKey.currentState!.pop();
  await tester.pumpAndSettle();
  expect(await h.pending, expected);
}
