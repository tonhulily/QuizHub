import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/design_system/app_theme.dart';
import 'package:quizhub/core/services/blocked_users.dart';
import 'package:quizhub/core/services/chat_realtime.dart';
import 'package:quizhub/core/services/post_events.dart';
import 'package:quizhub/core/services/social_events.dart';
import 'package:quizhub/data/models/author_model.dart';
import 'package:quizhub/data/models/auth_session.dart';
import 'package:quizhub/data/models/chat_models.dart';
import 'package:quizhub/data/models/comment_model.dart';
import 'package:quizhub/data/models/media_item.dart';
import 'package:quizhub/data/models/post_model.dart';
import 'package:quizhub/data/models/profile_model.dart';
import 'package:quizhub/data/repositories/chat_repository.dart';
import 'package:quizhub/data/repositories/feed_repository.dart';
import 'package:quizhub/data/repositories/friend_repository.dart';
import 'package:quizhub/data/repositories/post_repository.dart';
import 'package:quizhub/data/repositories/user_repository.dart';
import 'package:quizhub/di/locator.dart';
import 'package:quizhub/features/chat/view/chat_detail_view.dart';
import 'package:quizhub/features/chat/view/conversations_view.dart';
import 'package:quizhub/features/friends/widgets/person_card.dart';
import 'package:quizhub/features/home/home_tab.dart';
import 'package:quizhub/features/post/post_detail_view.dart';
import 'package:quizhub/features/profile/view/about_profile_view.dart';
import 'package:quizhub/features/profile/view/user_profile_view.dart';
import 'package:quizhub/features/shell/main_shell.dart';
import 'package:quizhub/shared/comment/comment_tile.dart';
import 'package:quizhub/shared/media/media_viewer.dart';
import 'package:quizhub/shared/post/post_card.dart';

import '../helpers/blocking_fixture.dart';
import '../helpers/chat_fixture.dart';
import '../helpers/fake_profile.dart';

Widget _app(Widget body) => withRole(
  UserRole.student,
  MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: body),
  ),
);

void main() {
  late BlockingFixture f;
  late UnfilteredSocialApi backend;
  late PostEvents postEvents;
  late SocialEvents social;
  setUp(() async {
    await getIt.reset();
    backend = UnfilteredSocialApi();
    f = await BlockingFixture.create(adapter: backend);
    postEvents = PostEvents();
    social = SocialEvents();
    getIt.registerSingleton<BlockedUsers>(f.blocks);
    getIt.registerSingleton<FeedRepository>(f.feed);
    getIt.registerSingleton<PostRepository>(f.posts);
    getIt.registerSingleton<UserRepository>(f.users);
    getIt.registerSingleton<ChatRepository>(f.chat);
    getIt.registerSingleton<PostEvents>(postEvents);
    getIt.registerSingleton<SocialEvents>(social);
  });
  tearDown(() async {
    await getIt.reset();
    await f.dispose();
    postEvents.dispose();
    social.dispose();
  });

  testWidgets('active home feed removes blocked posts/activities immediately', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const HomeTab()));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung bài 11'), findsOneWidget);
    await tester.runAsync(() => f.friends.block(2));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung bài 11'), findsNothing);
    expect(find.text('Lan'), findsNothing);
    expect(find.text('Nội dung bài 13'), findsOneWidget);
    await tester.runAsync(() => f.friends.unblock(2));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung bài 11'), findsOneWidget);
  });

  testWidgets('main shell syncs blocks before showing cached content', (
    tester,
  ) async {
    backend.blocked.add(2);
    getIt.registerSingleton<FriendRepository>(f.friends);
    expect(f.blocks.contains(2), isFalse);
    await tester.runAsync(() => f.feed.getFeed());
    expect(f.feed.cachedFirstPage!.items.length, 3);
    await tester.pumpWidget(_app(const MainShell()));
    await tester.pumpAndSettle();
    expect(f.blocks.contains(2), isTrue);
    expect(find.text('Nội dung bài 11'), findsNothing);
    expect(find.text('Nội dung bài 13'), findsOneWidget);
  });

  testWidgets('open media hides cached image when its owner is blocked', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const MediaViewer(
          userIds: [2],
          items: [MediaItem(url: 'https://example.test/private.jpg')],
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.runAsync(() => f.blocks.add(2, forUser: 1));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.text('Nội dung không khả dụng'), findsOneWidget);
  });

  testWidgets(
    'cached cards and comments hide; blocked-users manager remains usable',
    (tester) async {
      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            child: Column(
              children: [
                PostCard(post: PostModel.fromJson(blockingPost(11, 2))),
                const CommentTile(
                  comment: CommentModel(
                    commentId: 21,
                    content: 'Nội dung bình luận riêng',
                    author: AuthorModel(userId: 2, fullName: 'Lan'),
                  ),
                  onLike: null,
                ),
                const PersonCard(userId: 2, name: 'Lan'),
                const PersonCard(
                  userId: 2,
                  name: 'Lan (quản lý)',
                  allowBlocked: true,
                  primaryLabel: 'Bỏ chặn',
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Nội dung bài 11'), findsOneWidget);
      await tester.runAsync(() => f.blocks.add(2, forUser: 1));
      await tester.pumpAndSettle();
      expect(find.text('Nội dung bài 11'), findsNothing);
      expect(find.text('Nội dung bình luận riêng'), findsNothing);
      expect(find.text('Lan'), findsNothing);
      expect(find.text('Bình luận này không khả dụng'), findsOneWidget);
      expect(find.text('Lan (quản lý)'), findsOneWidget);
      await tester.runAsync(() => f.blocks.remove(2, forUser: 1));
      await tester.pumpAndSettle();
      expect(find.text('Nội dung bình luận riêng'), findsOneWidget);
    },
  );

  testWidgets(
    'open profile hides identity/posts after block and reloads on unblock',
    (tester) async {
      await tester.pumpWidget(_app(const UserProfileView(userId: 2)));
      await tester.pumpAndSettle();
      expect(find.text('Nội dung bài 11'), findsOneWidget);
      await tester.runAsync(() => f.friends.block(2));
      await tester.pumpAndSettle();
      expect(find.text('Lan'), findsNothing);
      expect(find.text('Nội dung bài 11'), findsNothing);
      expect(find.text('Tài khoản không khả dụng'), findsOneWidget);
      await tester.runAsync(() => f.friends.unblock(2));
      await tester.pumpAndSettle();
      expect(find.text('Nội dung bài 11'), findsOneWidget);
    },
  );

  testWidgets('cached About page cannot reveal a blocked identity', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const AboutProfileView(
          profile: ProfileModel(
            userId: 2,
            fullName: 'Lan',
            bio: 'Tiểu sử riêng',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tiểu sử riêng'), findsOneWidget);
    await tester.runAsync(() => f.blocks.add(2, forUser: 1));
    await tester.pumpAndSettle();
    expect(find.text('Tiểu sử riêng'), findsNothing);
    expect(find.text('Lan'), findsNothing);
    expect(find.text('Tài khoản không khả dụng'), findsOneWidget);
  });

  testWidgets('open post detail cannot keep showing blocked author content', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const PostDetailView(postId: 11)));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung bài 11'), findsOneWidget);
    await tester.runAsync(() => f.friends.block(2));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung bài 11'), findsNothing);
    expect(find.text('Lan'), findsNothing);
  });

  testWidgets(
    'open chat hides history, identity and composer; unblock restores history',
    (tester) async {
      final chat = ChatFixture();
      getIt.registerSingleton<ChatRealtime>(chat.data.realtime);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await chat.dispose();
      });
      await tester.pumpWidget(
        _app(
          const ChatDetailView(
            target: ChatTarget.conversation(
              ChatConversation(
                conversationId: 1,
                title: 'Lan',
                members: [
                  AuthorModel(userId: 1, fullName: 'Tôi'),
                  AuthorModel(userId: 2, fullName: 'Lan'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tin riêng 1'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Bản nháp của tôi');
      await tester.runAsync(() => f.friends.block(2));
      await tester.pumpAndSettle();
      expect(find.text('Lan'), findsNothing);
      expect(find.text('Tin riêng 1'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Không thể xem cuộc trò chuyện'), findsOneWidget);
      await tester.runAsync(() => f.friends.unblock(2));
      await tester.pumpAndSettle();
      expect(find.text('Tin riêng 1'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Bản nháp của tôi'), findsOneWidget);
    },
  );

  testWidgets('conversation list removes blocked cached summary and preview', (
    tester,
  ) async {
    final chat = ChatFixture();
    getIt.registerSingleton<ChatRealtime>(chat.data.realtime);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await chat.dispose();
    });
    await tester.pumpWidget(_app(const ConversationsView()));
    await tester.pumpAndSettle();
    expect(find.text('Lan'), findsOneWidget);
    await tester.runAsync(() => f.friends.block(2));
    await tester.pumpAndSettle();
    expect(find.text('Lan'), findsNothing);
    expect(find.text('Tin riêng 1'), findsNothing);
    expect(find.text('Minh'), findsOneWidget);
  });
}
