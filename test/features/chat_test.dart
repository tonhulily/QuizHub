import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/design_system/app_theme.dart';
import 'package:quizhub/core/services/chat_realtime.dart';
import 'package:quizhub/core/services/social_events.dart';
import 'package:quizhub/dev/preview_chat.dart';
import 'package:quizhub/data/models/auth_session.dart';
import 'package:quizhub/data/models/chat_models.dart';
import 'package:quizhub/data/repositories/chat_repository.dart';
import 'package:quizhub/di/locator.dart';
import 'package:quizhub/features/chat/cubit/chat_detail_cubit.dart';
import 'package:quizhub/features/chat/view/chat_detail_view.dart';
import '../helpers/chat_fixture.dart';
import '../helpers/fake_profile.dart';

class _NoEcho extends PreviewChatRealtime {
  _NoEcho(super.backend);
  @override
  void send({
    required int conversationId,
    required String content,
    String messageType = 'TEXT',
    List<String> mediaUrls = const [],
  }) {
    backend.append(conversationId, 1, content, messageType, mediaUrls);
  }
}

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
    'block/unblock đang mở chat cập nhật quyền gửi mà không cần mở lại màn',
    () async {
      final social = SocialEvents();
      final conversation = await fixture.repo.direct(2, myId: 1);
      final cubit = ChatDetailCubit(
        fixture.repo,
        target: ChatTarget.conversation(conversation),
        myId: 1,
        realtime: fixture.data.realtime,
        socialEvents: social,
      );
      await cubit.load();
      fixture.blocked.add(2);
      final restricted = cubit.stream.firstWhere((s) => s.sendRestricted);
      social.notifyChanged();
      await restricted;
      final before = fixture.data.messages[1]!.length;
      expect(await cubit.send('Không gửi khi bị chặn'), isNotNull);
      expect(fixture.data.messages[1], hasLength(before));
      fixture.blocked.clear();
      final enabled = cubit.stream.firstWhere(
        (s) => !s.sendRestricted && !s.checkingAccess,
      );
      social.notifyChanged();
      await enabled;
      expect(await cubit.send('Đã bỏ chặn'), isNull);
      await cubit.close();
      social.dispose();
    },
  );

  test('snapshot REST cũ không khôi phục tin đã thu hồi', () {
    const message = ChatMessage(
      messageId: 5,
      conversationId: 1,
      content: 'Nội dung cũ',
    );
    final merged = ChatDetailCubit.mergeMessages(
      [message.asRevoked()],
      [message],
    );
    expect(merged.single.revoked, isTrue);
    expect(merged.single.content, isEmpty);
  });

  test('thiếu echo không tự gửi lại; tải bù tìm đúng tin đã lưu', () async {
    final live = _NoEcho(fixture.data);
    final conversation = await fixture.repo.direct(2, myId: 1);
    final cubit = ChatDetailCubit(
      fixture.repo,
      target: ChatTarget.conversation(conversation),
      myId: 1,
      realtime: live,
      confirmationTimeout: const Duration(milliseconds: 20),
    );
    await cubit.load();
    expect(await cubit.send('Chưa nhận echo'), isNotNull);
    expect(cubit.state.unconfirmed, isTrue);
    expect(await cubit.send('Chưa nhận echo'), isNotNull);
    expect(await cubit.reconcilePending(), isTrue);
    expect(cubit.state.unconfirmed, isFalse);
    expect(
      fixture.data.messages[1]!.where((m) => m['content'] == 'Chưa nhận echo'),
      hasLength(1),
    );
    await cubit.close();
    await live.dispose();
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
      getIt.registerSingleton<SocialEvents>(
        SocialEvents(),
        dispose: (value) => value.dispose(),
      );
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
