import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/design_system/app_theme.dart';
import 'package:quizhub/core/services/chat_realtime.dart';
import 'package:quizhub/data/models/auth_session.dart';
import 'package:quizhub/data/models/chat_models.dart';
import 'package:quizhub/data/repositories/chat_repository.dart';
import 'package:quizhub/di/locator.dart';
import 'package:quizhub/features/chat/cubit/chat_detail_cubit.dart';
import 'package:quizhub/features/chat/view/chat_detail_view.dart';
import '../helpers/chat_fixture.dart';
import '../helpers/fake_profile.dart';

void main() {
  late ChatFixture fixture;
  setUp(() {
    fixture = ChatFixture();
  });
  tearDown(() async {
    await getIt.reset();
    await fixture.dispose();
  });

  test(
    'echo xác nhận gửi đúng một tin, nhận tin người khác không cần làm mới',
    () async {
      final conversation = await fixture.repo.direct(2, myId: 1);
      final cubit = ChatDetailCubit(
        fixture.repo,
        target: ChatTarget.conversation(conversation),
        myId: 1,
        realtime: fixture.data.realtime,
      );
      await cubit.load();
      expect(await cubit.send('Chào bạn'), isNull);
      expect(
        cubit.state.messages.where((m) => m.content == 'Chào bạn'),
        hasLength(1),
      );
      expect(cubit.state.sending, isFalse);
      expect(cubit.state.refreshing, isFalse);
      await cubit.load();
      expect(
        cubit.state.messages.where((m) => m.content == 'Chào bạn'),
        hasLength(1),
      );
      await cubit.close();
    },
  );

  test('mất kết nối không gửi, kết nối lại tải bù tin đã bỏ lỡ', () async {
    final conversation = await fixture.repo.direct(2, myId: 1);
    final live = fixture.data.realtime;
    final cubit = ChatDetailCubit(
      fixture.repo,
      target: ChatTarget.conversation(conversation),
      myId: 1,
      realtime: live,
    );
    await cubit.load();
    live.pause();
    expect(await cubit.send('Không được gửi'), isNotNull);
    fixture.data.append(1, 2, 'Tin khi mất mạng', 'TEXT', []);
    final restored = cubit.stream.firstWhere(
      (s) => s.messages.any((m) => m.content == 'Tin khi mất mạng'),
    );
    await live.resume();
    await restored.timeout(const Duration(seconds: 2));
    expect(
      cubit.state.messages.where((m) => m.content == 'Tin khi mất mạng'),
      hasLength(1),
    );
    expect(
      cubit.state.messages.any((m) => m.content == 'Không được gửi'),
      isFalse,
    );
    await cubit.close();
  });

  testWidgets(
    'ô soạn gửi tin, xoá nội dung khi xác nhận và giữ nháp lúc offline',
    (tester) async {
      getIt.registerSingleton<ChatRepository>(fixture.repo);
      getIt.registerSingleton<ChatRealtime>(fixture.data.realtime);
      await tester.pumpWidget(
        withRole(
          UserRole.student,
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ChatDetailView(
              target: ChatTarget.conversation(
                ChatConversation(conversationId: 1, title: 'Bạn 2'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Tin nhắn thử');
      await tester.pump();
      await tester.tap(find.byTooltip('Gửi tin nhắn'));
      await tester.pumpAndSettle();
      expect(find.text('Tin nhắn thử'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.enterText(find.byType(TextField), 'Nội dung nháp');
      fixture.data.realtime.pause();
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Gửi tin nhắn',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Nội dung nháp',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
