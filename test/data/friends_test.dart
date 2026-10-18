import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/api_exception.dart';
import 'package:quizhub/core/services/social_events.dart';
import 'package:quizhub/core/network/session_events.dart';
import 'package:quizhub/core/storage/token_storage.dart';
import 'package:quizhub/data/models/auth_session.dart';
import 'package:quizhub/data/models/profile_model.dart';
import 'package:quizhub/data/repositories/friend_repository.dart';
import 'package:quizhub/data/repositories/user_search_repository.dart';
import 'package:quizhub/features/friends/cubit/friends_cubit.dart';
import 'package:quizhub/features/friends/cubit/user_search_cubit.dart';
import 'package:quizhub/features/profile/cubit/user_relation_cubit.dart';

/// Backend giả định tuyến theo "METHOD path".
class _Backend implements HttpClientAdapter {
  final Map<String, ResponseBody Function(RequestOptions o)> routes = {};
  final List<String> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${o.method} ${o.path}';
    calls.add(key);
    final handler = routes[key];
    if (handler == null) return _ok(null);
    return handler(o);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Map<String, dynamic> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ResponseBody _ok(dynamic data) =>
    _json(200, {'code': '0000', 'message': 'ok', 'data': data});

ResponseBody _fail(int status) =>
    _json(status, {'code': '9999', 'message': 'lỗi giả'});

Map<String, dynamic> _page(List<dynamic> items, {bool hasNext = false}) => {
  'items': items,
  'pagination': {'after': null, 'has_next': hasNext},
};

Map<String, dynamic> _searchPage(
  List<Map<String, dynamic>> users, {
  required int total,
  int? after,
}) => {
  'items': [
    for (final u in users) {'type': 'USER', 'relevance_score': 1.0, 'user': u},
  ],
  'pagination': {'after': after, 'has_next': after != null && after < total},
  'total_hits': total,
};

Map<String, dynamic> _user(
  int id, {
  String role = 'STUDENT',
  String? email,
  String name = 'User',
}) => {
  'user_id': id,
  'full_name': '$name $id',
  'student_lecturer_code': '2023${1000 + id}',
  'email': email ?? 'u$id@sis.hust.edu.vn',
  'role': role,
  'school_faculty': 'CNTT',
};

class _Tokens extends TokenStorage {
  @override
  String? get accessToken => 'a';
  @override
  String? get refreshToken => 'r';
  @override
  bool get hasTokens => true;
  @override
  Future<void> load() async {}
}

void main() {
  late _Backend backend;
  late FriendRepository friends;
  late UserSearchRepository search;

  setUp(() {
    backend = _Backend();
    final api = ApiClient(
      tokens: _Tokens(),
      events: SessionEvents(),
      baseUrl: 'https://example.com/api/v1',
      adapter: backend,
    );
    friends = FriendRepository(api);
    search = UserSearchRepository(api, friends);
  });

  group('email -> code', () {
    test('derives the student code from the school email', () {
      expect(
        UserSearchRepository.codeFromEmail('Tung.VN236058@sis.hust.edu.vn'),
        '20236058',
      );
      expect(
        UserSearchRepository.codeFromEmail('Nhu.MT235184@sis.hust.edu.vn'),
        '20235184',
      );
      expect(
        UserSearchRepository.codeFromEmail('Tuan.VM2417270@sis.hust.edu.vn'),
        '202417270',
      );
    });

    test('returns null when there is no trailing number', () {
      expect(UserSearchRepository.codeFromEmail('abc@example.com'), isNull);
      expect(UserSearchRepository.codeFromEmail('a1@example.com'), isNull);
    });

    test('looksLikeEmail', () {
      expect(UserSearchRepository.looksLikeEmail('a@b.vn'), true);
      expect(UserSearchRepository.looksLikeEmail('  a@b.vn '), true);
      expect(UserSearchRepository.looksLikeEmail('Vũ Ngọc Tùng'), false);
      expect(UserSearchRepository.looksLikeEmail('20236058'), false);
    });
  });

  group('search', () {
    test('parses users, offset pagination and total hits', () async {
      backend.routes['GET /search'] = (o) =>
          _ok(_searchPage([_user(2), _user(3)], total: 224, after: 2));

      final page = await search.searchUsers('tung');

      expect(page.items.map((u) => u.userId), [2, 3]);
      expect(page.totalHits, 224);
      expect(page.nextOffset, 2);
      expect(page.hasNext, true);
      expect(page.items.first.subtitle, contains('CNTT'));
    });

    test(
      'findByEmail searches by derived code and matches the exact email',
      () async {
        String? queried;
        backend.routes['GET /search'] = (o) {
          queried = o.queryParameters['query'] as String?;
          return _ok(
            _searchPage([
              _user(7, email: 'Khac.AB236059@sis.hust.edu.vn'),
              _user(8, email: 'Tung.VN236058@sis.hust.edu.vn'),
            ], total: 2),
          );
        };

        final found = await search.findByEmail('tung.vn236058@SIS.hust.edu.vn');

        expect(queried, '20236058');
        expect(found?.userId, 8);
      },
    );

    test('findByEmail returns null when nobody has that email', () async {
      backend.routes['GET /search'] = (o) => _ok(_searchPage([], total: 0));
      expect(await search.findByEmail('ai.do123456@sis.hust.edu.vn'), isNull);
      expect(await search.findByEmail('không phải email'), isNull);
    });
  });

  group('friends API parsing', () {
    test('friend list, received and sent requests', () async {
      backend.routes['GET /friendships'] = (o) => _ok({
        ..._page([
          {
            'user_id': 11,
            'full_name': 'Bạn A',
            'friends_since': '2026-10-01T00:00:00Z',
            'mutual_friends_count': 3,
          },
        ]),
        'total_friends': 1,
      });
      backend.routes['GET /friendships/requests/received'] = (o) => _ok(
        _page([
          {
            'requester': {'user_id': 13, 'full_name': 'Người gửi'},
            'status': 'PENDING',
            'mutual_friends_count': 2,
          },
        ]),
      );
      backend.routes['GET /friendships/requests/sent'] = (o) => _ok(
        _page([
          {
            'receiver': {'user_id': 12, 'full_name': 'Người nhận'},
            'status': 'PENDING',
          },
        ]),
      );

      final f = await friends.friends();
      final r = await friends.receivedRequests();
      final s = await friends.sentRequests();

      expect(f.items.single.mutualFriendsCount, 3);
      expect(r.items.single.user.userId, 13);
      expect(r.items.single.sentByMe, false);
      expect(r.items.single.mutualFriendsCount, 2);
      expect(s.items.single.user.userId, 12);
      expect(s.items.single.sentByMe, true);
    });

    test('sendRequest returns the server status', () async {
      backend.routes['POST /friendships/request'] = (o) {
        expect(o.data, {'addressee_id': 5});
        return _ok({'status': 'ACCEPTED'});
      };
      expect(await friends.sendRequest(5), 'ACCEPTED');
    });
  });

  group('suggestions', () {
    void stubBackend() {
      backend.routes['GET /friendships'] = (o) => _ok(
        _page([
          {'user_id': 11, 'full_name': 'Bạn'},
        ]),
      );
      backend.routes['GET /friendships/requests/sent'] = (o) => _ok(
        _page([
          {
            'receiver': {'user_id': 12, 'full_name': 'Đã gửi'},
          },
        ]),
      );
      backend.routes['GET /friendships/requests/received'] = (o) => _ok(
        _page([
          {
            'requester': {'user_id': 13, 'full_name': 'Đã nhận'},
          },
        ]),
      );
      backend.routes['GET /blocks'] = (o) => _ok(
        _page([
          {'user_id': 14, 'full_name': 'Đã chặn'},
        ]),
      );
      final everyone = [
        _user(1), // chính mình
        _user(11), _user(12), _user(13), _user(14), // đã có quan hệ
        _user(15),
        _user(16, role: 'LECTURER'), // khác vai trò
        _user(17),
      ];
      backend.routes['GET /search'] = (o) {
        final limit = o.queryParameters['limit'] as int;
        return limit == 1
            ? _ok(_searchPage(everyone.take(1).toList(), total: 8, after: 1))
            : _ok(_searchPage(everyone, total: 8));
      };
    }

    test('excludes me, existing relations, blocked and other roles', () async {
      stubBackend();
      final list = await search.suggestions(
        myUserId: 1,
        myRole: UserRole.student,
        random: Random(1),
      );
      expect(list.map((u) => u.userId).toSet(), {15, 17});
    });

    test('reuses known relations instead of refetching the lists', () async {
      stubBackend();
      backend.calls.clear();

      final list = await search.suggestions(
        myUserId: 1,
        myRole: UserRole.student,
        alreadyRelated: {11, 12, 13},
        random: Random(1),
      );

      expect(list.map((u) => u.userId).toSet(), {15, 17});
      expect(backend.calls, isNot(contains('GET /friendships')));
      expect(backend.calls, isNot(contains('GET /friendships/requests/sent')));
      expect(
        backend.calls,
        isNot(contains('GET /friendships/requests/received')),
      );
      // Danh sách chặn vẫn phải hỏi vì state của tab không có
      expect(backend.calls, contains('GET /blocks'));
    });

    test('empty system gives no suggestions', () async {
      stubBackend();
      backend.routes['GET /search'] = (o) => _ok(_searchPage([], total: 0));
      final list = await search.suggestions(
        myUserId: 1,
        myRole: UserRole.student,
      );
      expect(list, isEmpty);
    });
  });

  group('FriendsCubit', () {
    late SocialEvents events;
    late FriendsCubit cubit;

    setUp(() {
      events = SocialEvents();
      backend.routes['GET /friendships'] = (o) => _ok(_page([]));
      backend.routes['GET /friendships/requests/sent'] = (o) => _ok(_page([]));
      backend.routes['GET /friendships/requests/received'] = (o) => _ok(
        _page([
          {
            'requester': {'user_id': 13, 'full_name': 'Người gửi'},
            'mutual_friends_count': 1,
          },
        ]),
      );
      backend.routes['GET /blocks'] = (o) => _ok(_page([]));
      backend.routes['GET /search'] = (o) {
        final limit = o.queryParameters['limit'] as int;
        final users = [_user(1), _user(21), _user(22)];
        return limit == 1
            ? _ok(_searchPage(users.take(1).toList(), total: 3, after: 1))
            : _ok(_searchPage(users, total: 3));
      };
      cubit = FriendsCubit(
        friends,
        search,
        events,
        () => const ProfileModel(userId: 1, fullName: 'Tôi'),
      );
    });

    tearDown(() => cubit.close());

    test('load fills all three sections', () async {
      await cubit.load();
      final s = cubit.state;
      expect(s.requestsStatus, SectionStatus.loaded);
      expect(s.received.single.user.userId, 13);
      expect(s.suggestions.map((u) => u.userId).toSet(), {21, 22});
    });

    test('sendRequest moves a suggestion into the sent list', () async {
      await cubit.load();
      backend.routes['POST /friendships/request'] = (o) =>
          _ok({'status': 'PENDING'});
      final target = cubit.state.suggestions.first;

      final error = await cubit.sendRequest(target);

      expect(error, isNull);
      expect(
        cubit.state.suggestions.any((u) => u.userId == target.userId),
        false,
      );
      expect(cubit.state.sent.single.user.userId, target.userId);
      expect(cubit.state.busy, isEmpty);
    });

    test('accept moves a received request into friends', () async {
      await cubit.load();
      final request = cubit.state.received.single;

      expect(await cubit.accept(request), isNull);

      expect(cubit.state.received, isEmpty);
      expect(cubit.state.friends.single.userId, 13);
      expect(backend.calls, contains('POST /friendships/accept'));
    });

    test('decline removes the received request', () async {
      await cubit.load();
      expect(await cubit.decline(cubit.state.received.single), isNull);
      expect(cubit.state.received, isEmpty);
      expect(cubit.state.friends, isEmpty);
    });

    test('a failing action returns the error and keeps the list', () async {
      await cubit.load();
      backend.routes['POST /friendships/accept'] = (o) => _fail(400);

      final error = await cubit.accept(cubit.state.received.single);

      expect(error, isA<ApiException>());
      expect(cubit.state.received.length, 1);
      expect(cubit.state.busy, isEmpty);
    });

    test('dismissed suggestions do not come back on refresh', () async {
      await cubit.load();
      final id = cubit.state.suggestions.first.userId;
      cubit.dismissSuggestion(id);
      await cubit.refreshSuggestions();
      expect(cubit.state.suggestions.any((u) => u.userId == id), false);
    });

    test('a relation change event reloads the lists silently', () async {
      await cubit.load();
      backend.routes['GET /friendships'] = (o) => _ok(
        _page([
          {'user_id': 99, 'full_name': 'Mới kết bạn'},
        ]),
      );

      events.notifyChanged();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(cubit.state.friends.single.userId, 99);
    });
  });

  group('UserRelationCubit', () {
    late SocialEvents events;
    setUp(() => events = SocialEvents());

    UserRelationCubit make(RelationshipModel initial) =>
        UserRelationCubit(friends, events, userId: 5, initial: initial);

    test('pending relation resolves whether the request is incoming', () async {
      backend.routes['GET /friendships/requests/received'] = (o) => _ok(
        _page([
          {
            'requester': {'user_id': 5, 'full_name': 'Họ'},
          },
        ]),
      );
      final cubit = make(
        const RelationshipModel(friendRequestStatus: 'PENDING'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(cubit.state.incoming, true);
      await cubit.close();
    });

    test('pending relation I sent is not incoming', () async {
      backend.routes['GET /friendships/requests/received'] = (o) =>
          _ok(_page([]));
      final cubit = make(
        const RelationshipModel(friendRequestStatus: 'PENDING'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(cubit.state.incoming, false);
      await cubit.close();
    });

    test('addFriend -> PENDING, and notifies listeners', () async {
      backend.routes['POST /friendships/request'] = (o) =>
          _ok({'status': 'PENDING'});
      var notified = 0;
      events.onChanged.listen((_) => notified++);
      final cubit = make(const RelationshipModel());

      expect(await cubit.addFriend(), isNull);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.isPending, true);
      expect(cubit.state.incoming, false);
      expect(notified, 1);
      await cubit.close();
    });

    test('addFriend becomes ACCEPTED when they had already asked', () async {
      backend.routes['POST /friendships/request'] = (o) =>
          _ok({'status': 'ACCEPTED'});
      final cubit = make(const RelationshipModel());

      await cubit.addFriend();

      expect(cubit.state.isFriend, true);
      await cubit.close();
    });

    test('unfriend, follow toggle and block update the relationship', () async {
      final cubit = make(
        const RelationshipModel(
          isFriend: true,
          friendRequestStatus: 'ACCEPTED',
        ),
      );

      await cubit.unfriend();
      expect(cubit.state.isFriend, false);

      await cubit.toggleFollow();
      expect(cubit.state.relationship.isFollowing, true);
      await cubit.toggleFollow();
      expect(cubit.state.relationship.isFollowing, false);
      expect(
        backend.calls,
        containsAll(['POST /follows/5', 'DELETE /follows/5']),
      );

      await cubit.toggleFollow();
      await cubit.block();
      expect(cubit.state.relationship, const RelationshipModel());
      await cubit.close();
    });

    test('a failed request keeps the old relationship', () async {
      backend.routes['POST /friendships/request'] = (o) => _fail(400);
      final cubit = make(const RelationshipModel());

      final error = await cubit.addFriend();

      expect(error, isA<ApiException>());
      expect(cubit.state.relationship, const RelationshipModel());
      expect(cubit.state.busy, false);
      await cubit.close();
    });
  });

  group('UserSearchCubit', () {
    UserSearchCubit make() =>
        UserSearchCubit(search, debounce: const Duration(milliseconds: 5));

    test('empty query resets to idle', () async {
      final cubit = make();
      cubit.onQueryChanged('   ');
      expect(cubit.state.status, UserSearchStatus.idle);
      await cubit.close();
    });

    test('name query returns paged results', () async {
      backend.routes['GET /search'] = (o) =>
          _ok(_searchPage([_user(2), _user(3)], total: 30, after: 2));
      final cubit = make();

      await cubit.submit('tung');

      expect(cubit.state.status, UserSearchStatus.loaded);
      expect(cubit.state.items.length, 2);
      expect(cubit.state.totalHits, 30);
      expect(cubit.state.hasNext, true);
      expect(cubit.state.emailMode, false);
      await cubit.close();
    });

    test('loadMore appends the next page using the offset', () async {
      var call = 0;
      backend.routes['GET /search'] = (o) {
        call++;
        return call == 1
            ? _ok(_searchPage([_user(2)], total: 3, after: 1))
            : _ok(_searchPage([_user(3)], total: 3));
      };
      final cubit = make();
      await cubit.submit('a b');

      await cubit.loadMore();

      expect(cubit.state.items.map((u) => u.userId), [2, 3]);
      expect(cubit.state.hasNext, false);
      await cubit.close();
    });

    test('an email query uses email mode and returns at most one', () async {
      backend.routes['GET /search'] = (o) => _ok(
        _searchPage([
          _user(8, email: 'Tung.VN236058@sis.hust.edu.vn'),
        ], total: 1),
      );
      final cubit = make();

      await cubit.submit('Tung.VN236058@sis.hust.edu.vn');

      expect(cubit.state.emailMode, true);
      expect(cubit.state.items.single.userId, 8);
      await cubit.close();
    });

    test('network failure shows the failure state', () async {
      backend.routes['GET /search'] = (o) => _fail(500);
      final cubit = make();

      await cubit.submit('tung');

      expect(cubit.state.status, UserSearchStatus.failure);
      expect(cubit.state.error, isA<ApiException>());
      await cubit.close();
    });
  });
}
