import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/api_exception.dart';
import 'package:quizhub/core/network/session_events.dart';
import 'package:quizhub/core/services/blocked_users.dart';
import 'package:quizhub/data/models/comment_model.dart';
import 'package:quizhub/data/repositories/comment_repository.dart';
import 'package:quizhub/data/repositories/friend_repository.dart';
import 'package:quizhub/dev/preview_backend.dart';

import '../helpers/blocking_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BlockingFixture f;
  late UnfilteredSocialApi leaky;
  setUp(() async {
    leaky = UnfilteredSocialApi();
    f = await BlockingFixture.create(adapter: leaky);
  });
  tearDown(() => f.dispose());

  test(
    'FE filters blocked data even when API and feed cache still contain it',
    () async {
      await f.feed.getFeed();
      await f.friends.block(2);
      expect(f.blocks.contains(2), isTrue);
      expect(
        f.feed.cachedFirstPage!.items.every((i) => i.actor?.userId != 2),
        isTrue,
      );
      expect((await f.feed.getFeed()).items, hasLength(1));
      expect((await f.search.searchUsers('Lan')).items.map((u) => u.userId), [
        3,
      ]);
      expect((await f.friends.friends()).items.map((u) => u.userId), [3]);
      expect(
        (await f.friends.receivedRequests()).items.map((r) => r.user.userId),
        [3],
      );
      expect((await f.friends.sentRequests()).items.map((r) => r.user.userId), [
        3,
      ]);
      expect((await f.friends.followers()).items.map((u) => u.userId), [3]);
      expect((await f.friends.following()).items.map((u) => u.userId), [3]);
    },
  );

  test(
    'cached/direct profile, post, follow and friend actions cannot bypass block',
    () async {
      await f.friends.block(2);
      final blocked = isA<ApiException>().having(
        (e) => e.type,
        'type',
        ApiErrorType.forbidden,
      );
      await expectLater(f.users.getUser(2), throwsA(blocked));
      await expectLater(f.posts.getById(11), throwsA(blocked));
      expect(() => f.posts.userPosts(2), throwsA(blocked));
      expect(() => f.friends.follow(2), throwsA(blocked));
      expect(() => f.friends.sendRequest(2), throwsA(blocked));
      expect(() => f.friends.accept(2), throwsA(blocked));
      await expectLater(f.chat.direct(2, myId: 1), throwsA(blocked));
      expect(leaky.requests.any((o) => o.path == '/users/2'), isFalse);
      await f.friends.unblock(2);
      expect((await f.users.getUser(2)).userId, 2);
    },
  );

  test(
    'chat summaries/history are hidden even if server returns a blocked peer',
    () async {
      await f.friends.block(2);
      final list = await f.chat.conversations();
      expect(list.items.map((c) => c.conversationId), [2]);
      expect(list.items.single.members.map((u) => u.userId), [1, 3]);
      await expectLater(f.chat.messages(1), throwsA(isA<ApiException>()));
      expect(
        leaky.requests.any((o) => o.path == '/conversations/1/messages'),
        isFalse,
      );
    },
  );

  test(
    'block cache survives reopening, is scoped by account and preview/server',
    () async {
      await f.friends.block(2);
      final reopened = BlockedUsers(f.storage, scope: 'test');
      final otherEnvironment = BlockedUsers(f.storage, scope: 'server');
      addTearDown(reopened.dispose);
      addTearDown(otherEnvironment.dispose);
      expect(reopened.contains(2), isTrue);
      expect(otherEnvironment.contains(2), isFalse);
      await f.storage.setCachedUser(blockingUser(9));
      expect(reopened.ids, isEmpty);
      await reopened.add(3, forUser: 1);
      expect(reopened.ids, isEmpty);
      await f.storage.setCachedUser(blockingUser(1));
      expect(reopened.contains(2), isTrue);
    },
  );

  test('failed block request does not hide user locally', () async {
    leaky.rejectBlock = true;
    await expectLater(f.friends.block(2), throwsA(isA<ApiException>()));
    expect(f.blocks.ids, isEmpty);
    expect((await f.users.getUser(2)).userId, 2);
  });

  test(
    'block sync reads all pages and stale response cannot undo a new block',
    () async {
      var calls = 0;
      leaky.blocksPage = (o) async {
        calls++;
        return {
          'items': [blockingUser(o.queryParameters['after'] == null ? 2 : 3)],
          'pagination': {
            'has_next': o.queryParameters['after'] == null,
            'after': 'next',
          },
        };
      };
      expect(await f.friends.blockedIds(limit: 1), {2, 3});
      expect(calls, 2);
      final old = Completer<Map<String, dynamic>>();
      leaky.blocksPage = (_) => old.future;
      final syncing = f.friends.blockedIds();
      await Future<void>.delayed(Duration.zero);
      await f.blocks.add(4, forUser: 1);
      old.complete(blockingPage([]));
      await syncing;
      expect(f.blocks.ids, {2, 3, 4});
    },
  );

  test(
    'preview block filters content, comments and chat and persists through restart',
    () async {
      final backend = PreviewBackend(preferences: f.preferences);
      final session = SessionEvents();
      addTearDown(session.dispose);
      ApiClient apiFor(PreviewBackend value) => ApiClient(
        tokens: PreviewTokens(),
        events: session,
        baseUrl: 'https://example.test/api/v1',
        adapter: value,
      );
      var api = apiFor(backend);
      var friends = FriendRepository(api, blocks: f.blocks);
      final comments = CommentRepository(api);
      final thread = await api.post(
        '/conversations/direct',
        body: {'target_user_id': 3},
        parser: (d) => d as Map,
      );
      final conversationId = thread['conversation_id'];
      await friends.block(3);
      await expectLater(
        api.get('/users/3', parser: (d) => d),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        api.get('/posts/13', parser: (d) => d),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        api.get('/users/3/posts', parser: (d) => d),
        throwsA(isA<ApiException>()),
      );
      final feed = await api.get('/activity-feeds', parser: (d) => d as Map);
      expect(
        (feed['items'] as List).any((i) => i['actor']?['user_id'] == 3),
        isFalse,
      );
      final found = await api.get(
        '/search',
        query: {'type': 'USER', 'query': 'Minh'},
        parser: (d) => d as Map,
      );
      expect(
        (found['items'] as List).any((item) => item['user']['user_id'] == 3),
        isFalse,
      );
      final hidden = (await comments.list(
        targetType: TargetType.post,
        targetId: 12,
      )).items.first;
      expect(hidden.hidden, isTrue);
      expect(hidden.author, isNull);
      expect(hidden.content, isNull);
      expect(hidden.replyCount, 0);
      await expectLater(
        api.get('/conversations/$conversationId/messages', parser: (d) => d),
        throwsA(isA<ApiException>()),
      );

      api = apiFor(PreviewBackend(preferences: f.preferences));
      friends = FriendRepository(api, blocks: f.blocks);
      expect(await friends.blockedIds(), {3});
      await expectLater(
        api.get('/posts/13', parser: (d) => d),
        throwsA(isA<ApiException>()),
      );
      await friends.unblock(3);
      expect(
        (await api.get('/posts/13', parser: (d) => d as Map))['post_id'],
        13,
      );
      expect(f.blocks.ids, isEmpty);
    },
  );

  test(
    'preview block removes friendship/requests/follows without restoring on unblock',
    () async {
      final session = SessionEvents();
      addTearDown(session.dispose);
      ApiClient apiFor(PreviewBackend value) => ApiClient(
        tokens: PreviewTokens(),
        events: session,
        baseUrl: 'https://example.test/api/v1',
        adapter: value,
      );
      var friends = FriendRepository(
        apiFor(PreviewBackend(preferences: f.preferences)),
      );
      await friends.follow(2);
      await friends.block(2);
      friends = FriendRepository(
        apiFor(PreviewBackend(preferences: f.preferences)),
      );
      await friends.unblock(2);
      expect(
        (await friends.friends()).items.any((u) => u.userId == 2),
        isFalse,
      );
      expect(
        (await friends.following()).items.any((u) => u.userId == 2),
        isFalse,
      );
      expect(
        (await friends.followers()).items.any((u) => u.userId == 2),
        isFalse,
      );
    },
  );
}
