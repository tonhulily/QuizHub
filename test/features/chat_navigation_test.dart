import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/design_system/app_theme.dart';
import 'package:quizhub/core/router/app_routes.dart';
import 'package:quizhub/core/services/chat_realtime.dart';
import 'package:quizhub/core/services/social_events.dart';
import 'package:quizhub/data/models/auth_session.dart';
import 'package:quizhub/data/models/chat_models.dart';
import 'package:quizhub/data/repositories/chat_repository.dart';
import 'package:quizhub/di/locator.dart';
import 'package:quizhub/features/chat/view/chat_detail_view.dart';
import 'package:quizhub/features/chat/view/conversations_view.dart';

import '../helpers/chat_fixture.dart';
import '../helpers/fake_profile.dart';

void main() {
  testWidgets(
    'danh sách → chat → gửi → quay lại → mở lại giữ tin, không lỗi build',
    (tester) async {
      await getIt.reset();
      final fixture = ChatFixture();
      getIt.registerSingleton<ChatRepository>(fixture.repo);
      getIt.registerSingleton<ChatRealtime>(fixture.data.realtime);
      getIt.registerSingleton<SocialEvents>(
        SocialEvents(),
        dispose: (events) => events.dispose(),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await getIt.reset();
        await fixture.dispose();
      });

      // Dùng cùng Navigator: màn danh sách vẫn còn trong stack khi mở chat.
      await tester.pumpWidget(
        withRole(
          UserRole.student,
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ConversationsView(),
            onGenerateRoute: (settings) {
              if (settings.name == AppRoutes.chatDetail) {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) =>
                      ChatDetailView(target: settings.arguments! as ChatTarget),
                );
              }
              return null;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(fixture.data.realtime.connection, ChatConnection.connected);

      await tester.tap(find.byKey(const ValueKey('conversation_1')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ChatDetailView), findsOneWidget);
      expect(
        find.byType(ConversationsView, skipOffstage: false),
        findsOneWidget,
      );

      const message = 'Tin nhắn kiểm tra chuyển màn';
      await tester.enterText(find.byType(TextField), message);
      await tester.pump();
      await tester.tap(find.byTooltip('Gửi tin nhắn'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(message), findsOneWidget);
      expect(
        fixture.data.messages[1]!.where(
          (m) => m['sender_id'] == 1 && m['content'] == message,
        ),
        hasLength(1),
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ChatDetailView), findsNothing);
      expect(find.byType(ConversationsView), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('conversation_1')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ChatDetailView), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(
        fixture.data.messages[1]!.where(
          (m) => m['sender_id'] == 1 && m['content'] == message,
        ),
        hasLength(1),
      );
    },
  );
}
