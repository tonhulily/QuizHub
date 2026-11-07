import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/design_system/app_theme.dart';
import 'package:quizhub/core/network/api_exception.dart';
import 'package:quizhub/core/services/chat_realtime.dart';
import 'package:quizhub/core/services/social_events.dart';
import 'package:quizhub/data/models/auth_session.dart';
import 'package:quizhub/data/models/chat_models.dart';
import 'package:quizhub/data/models/cursor_page.dart';
import 'package:quizhub/data/repositories/chat_repository.dart';
import 'package:quizhub/di/locator.dart';
import 'package:quizhub/features/chat/view/chat_detail_view.dart';
import 'package:quizhub/features/chat/view/conversations_view.dart';
import 'package:quizhub/features/chat/widgets/chat_message_tile.dart';
import 'package:quizhub/shared/media/media_viewer.dart';
import '../helpers/chat_fixture.dart';
import '../helpers/fake_profile.dart';

class _Pages implements ChatRepository {
  final requests = <String?>[];
  bool failHistory = false;
  @override
  Future<CursorPage<ChatConversation>> conversations({String? after}) async {
    requests.add(after);
    return after == null
        ? CursorPage(
            items: [
              ChatConversation(
                conversationId: 1,
                title: 'Trần Thị Lan',
                unreadCount: 2,
                updatedAt: DateTime.now(),
                lastMessage: const ChatMessage(
                  messageId: 1,
                  conversationId: 1,
                  senderId: 2,
                  content: 'Mai mình học nhé',
                ),
              ),
            ],
            after: 'next',
            hasNext: true,
          )
        : const CursorPage(
            items: [
              ChatConversation(
                conversationId: 2,
                title: 'Lê Quang Minh',
                lastMessage: ChatMessage(
                  messageId: 2,
                  conversationId: 2,
                  senderId: 1,
                  content: 'Em gửi bài rồi ạ',
                ),
              ),
            ],
          );
  }

  @override
  Future<CursorPage<ChatMessage>> messages(int id, {String? after}) async {
    if (failHistory) {
      throw const ApiException(
        type: ApiErrorType.noConnection,
        message: 'Mất mạng',
      );
    }
    return const CursorPage(items: []);
  }

  @override
  Future<bool> blockedWith(int id) async => false;
  @override
  Future<List<Never>> members(int id) async => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget body) => withRole(
  UserRole.student,
  MaterialApp(theme: AppTheme.lightTheme, home: body),
);

Future<ChatFixture> _setup(WidgetTester tester, {ChatRepository? repo}) async {
  await getIt.reset();
  final fixture = ChatFixture();
  getIt.registerSingleton<ChatRepository>(repo ?? fixture.repo);
  getIt.registerSingleton<ChatRealtime>(fixture.data.realtime);
  getIt.registerSingleton<SocialEvents>(
    SocialEvents(),
    dispose: (v) => v.dispose(),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await getIt.reset();
    await fixture.dispose();
  });
  return fixture;
}

void main() {
  testWidgets('tìm hội thoại đọc cả trang cũ và lọc được chưa đọc', (
    tester,
  ) async {
    final repo = _Pages();
    await _setup(tester, repo: repo);
    await tester.pumpWidget(_app(const ConversationsView()));
    await tester.pumpAndSettle();
    expect(find.text('Trần Thị Lan'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('conversation_search')),
      'Minh',
    );
    await tester.pumpAndSettle();
    expect(repo.requests, contains('next'));
    expect(find.text('Lê Quang Minh'), findsOneWidget);
    expect(find.text('Trần Thị Lan'), findsNothing);
    await tester.tap(find.byTooltip('Xoá tìm kiếm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chưa đọc'));
    await tester.pumpAndSettle();
    expect(find.text('Trần Thị Lan'), findsOneWidget);
    expect(find.text('Lê Quang Minh'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('conversation_search')),
      'Không tồn tại',
    );
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy cuộc trò chuyện'), findsOneWidget);
  });

  testWidgets('ảnh hiện trong bong bóng và bấm mở toàn màn hình', (
    tester,
  ) async {
    await _setup(tester);
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: ChatMessageTile(
            message: const ChatMessage(
              messageId: 9,
              conversationId: 1,
              senderId: 2,
              messageType: 'IMAGE',
              mediaUrls: ['https://example.test/photo.jpg'],
            ),
            mine: false,
            onLongPress: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Xem ảnh'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(MediaViewer), findsOneWidget);
  });

  testWidgets('thích nhanh gửi tin và nhấn giữ mở các thao tác của tin mình', (
    tester,
  ) async {
    final fixture = await _setup(tester);
    await tester.pumpWidget(
      _app(
        const ChatDetailView(
          target: ChatTarget.conversation(
            ChatConversation(conversationId: 1, title: 'Lan'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Gửi lượt thích'));
    await tester.pumpAndSettle();
    expect(
      fixture.data.messages[1]!.any(
        (m) => m['sender_id'] == 1 && m['content'] == '👍',
      ),
      isTrue,
    );
    await tester.longPress(find.text('👍'));
    await tester.pumpAndSettle();
    expect(find.text('Sao chép'), findsOneWidget);
    expect(find.text('Xoá ở phía tôi'), findsOneWidget);
    expect(find.text('Thu hồi với mọi người'), findsOneWidget);
  });

  testWidgets('lỗi lịch sử hiện Thử lại và khoá gửi; bấm lại vào được chat', (
    tester,
  ) async {
    final repo = _Pages()..failHistory = true;
    await _setup(tester, repo: repo);
    await tester.pumpWidget(
      _app(
        const ChatDetailView(
          target: ChatTarget.conversation(
            ChatConversation(conversationId: 1, title: 'Lan'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Gửi lượt thích',
            ),
          )
          .onPressed,
      isNull,
    );
    repo.failHistory = false;
    await tester.tap(find.text('Thử lại').first);
    await tester.pumpAndSettle();
    expect(
      find.text('Bắt đầu cuộc trò chuyện bằng một lời chào.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Gửi lượt thích',
            ),
          )
          .onPressed,
      isNotNull,
    );
  });
}
