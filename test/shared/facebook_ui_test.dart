import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/design_system/app_theme.dart';
import 'package:quizhub/core/services/post_events.dart';
import 'package:quizhub/data/models/author_model.dart';
import 'package:quizhub/data/models/feed_item.dart';
import 'package:quizhub/data/models/post_model.dart';
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
    await tester.pumpWidget(
      _host(PostCard(post: _post(), onShare: (p) => shared = p)),
    );

    await tester.tap(find.text('Chia sẻ'));
    await tester.pump();
    expect(shared?.postId, 7);
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
