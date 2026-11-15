import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/design_system/app_theme.dart';
import 'package:quizhub/core/design_system/app_icons.dart';
import 'package:quizhub/core/services/post_events.dart';
import 'package:quizhub/core/widgets/user_avatar.dart';
import 'package:quizhub/data/models/author_model.dart';
import 'package:quizhub/data/models/comment_model.dart';
import 'package:quizhub/data/models/feed_item.dart';
import 'package:quizhub/data/models/post_model.dart';
import 'package:quizhub/data/models/react_result.dart';
import 'package:quizhub/data/repositories/reaction_repository.dart';
import 'package:quizhub/di/locator.dart';
import 'package:quizhub/shared/post/post_card.dart';

PostModel _post({int likes = 5, int comments = 2, bool liked = false}) =>
    PostModel(
      postId: 7,
      content: 'Xin chào QuizHub',
      author: const AuthorModel(userId: 2, fullName: 'Trần Thị Lan'),
      reactCount: likes,
      commentCount: comments,
      reactedByMe: liked,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    );

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

class _Reactions implements ReactionRepository {
  int toggles = 0;

  @override
  Future<ReactResult> toggleLike({
    required TargetType targetType,
    required int targetId,
  }) async {
    toggles++;
    return const ReactResult(myReaction: 'LIKE', totalCount: 6);
  }
}

void main() {
  testWidgets('PostCard shows Facebook-style header, counts and 3 actions', (
    tester,
  ) async {
    await tester.pumpWidget(_host(PostCard(post: _post())));

    expect(find.text('Trần Thị Lan'), findsOneWidget);
    expect(find.text('Xin chào QuizHub'), findsOneWidget);
    expect(find.text('2 bình luận'), findsOneWidget);
    expect(find.text('Thích'), findsOneWidget);
    expect(find.text('Bình luận'), findsOneWidget);
    expect(find.text('Chia sẻ'), findsOneWidget);
  });

  testWidgets('Share button calls onShare when provided', (tester) async {
    PostModel? shared;
    var openedDetails = 0;
    await tester.pumpWidget(
      _host(
        PostCard(
          post: _post(),
          onTap: (_) => openedDetails++,
          onShare: (p) => shared = p,
        ),
      ),
    );

    await tester.tap(find.text('Chia sẻ'));
    await tester.pump();
    expect(shared?.postId, 7);
    expect(openedDetails, 0);
  });

  testWidgets('white space and post metadata open the post exactly once', (
    tester,
  ) async {
    final opened = <int>[];
    var openedAuthors = 0;
    await tester.pumpWidget(
      _host(
        PostCard(
          post: _post(),
          onTap: (p) => opened.add(p.postId),
          onTapAuthor: (_) => openedAuthors++,
        ),
      ),
    );
    final card = tester.getRect(find.byType(PostCard));
    final text = tester.getRect(find.text('Xin chào QuizHub'));
    // Khoảng trắng bên phải nội dung, ngoài vùng chữ được bấm ở bản cũ.
    await tester.tapAt(Offset(card.right - 8, text.center.dy));
    await tester.pump();
    expect(opened, [7]);

    final author = tester.getRect(find.text('Trần Thị Lan'));
    await tester.tapAt(Offset(card.center.dx, author.center.dy));
    await tester.pump();
    expect(opened, [7, 7]);
    expect(openedAuthors, 0);

    await tester.tap(find.byIcon(AppIcons.audienceEveryone));
    await tester.pump();
    expect(opened, [7, 7, 7]);

    await tester.tap(find.text('Xin chào QuizHub'));
    await tester.pump();
    expect(opened, [7, 7, 7, 7]);
  });

  testWidgets('author name and avatar retain profile action', (tester) async {
    var openedDetails = 0;
    final openedAuthors = <int>[];
    await tester.pumpWidget(
      _host(
        PostCard(
          post: _post(),
          onTap: (_) => openedDetails++,
          onTapAuthor: (p) => openedAuthors.add(p.author.userId),
        ),
      ),
    );
    await tester.tap(find.text('Trần Thị Lan'));
    await tester.pump();
    await tester.tap(find.byType(UserAvatar));
    await tester.pump();
    expect(openedAuthors, [2, 2]);
    expect(openedDetails, 0);
  });

  testWidgets('Like retains its action without opening the post', (
    tester,
  ) async {
    final reactions = _Reactions();
    getIt.registerSingleton<ReactionRepository>(reactions);
    addTearDown(() => getIt.unregister<ReactionRepository>());
    var openedDetails = 0;
    await tester.pumpWidget(
      _host(PostCard(post: _post(), onTap: (_) => openedDetails++)),
    );
    await tester.tap(find.text('Thích'));
    await tester.pumpAndSettle();
    expect(reactions.toggles, 1);
    expect(openedDetails, 0);
    expect(find.byIcon(AppIcons.likeFill), findsNWidgets(2));
  });

  testWidgets('See more expands content without opening the post', (
    tester,
  ) async {
    var openedDetails = 0;
    await tester.pumpWidget(
      _host(
        PostCard(
          post: _post().copyWith(
            content: List.filled(60, 'Nội dung bài viết dài.').join(' '),
          ),
          onTap: (_) => openedDetails++,
        ),
      ),
    );
    expect(find.text('Xem thêm'), findsOneWidget);
    await tester.tap(find.text('Xem thêm'));
    await tester.pump();
    expect(find.text('Xem thêm'), findsNothing);
    expect(openedDetails, 0);
  });

  test('FeedItem.fromPost exposes the same post to the feed', () {
    final item = FeedItem.fromPost(_post());
    expect(item.isPost, true);
    expect(item.toPost()?.postId, 7);
    expect(item.feedId, -7);
  });

  test('PostEvents broadcasts published posts to every listener', () async {
    final events = PostEvents();
    final a = events.onPublished.first;
    final b = events.onPublished.first;

    events.publish(_post());

    expect((await a).postId, 7);
    expect((await b).postId, 7);
    events.dispose();
  });
}
