import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/api_exception.dart';
import 'package:quizhub/core/network/session_events.dart';
import 'package:quizhub/core/storage/local_storage.dart';
import 'package:quizhub/core/storage/token_storage.dart';
import 'package:quizhub/data/repositories/feed_repository.dart';
import 'package:quizhub/data/repositories/post_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Adapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions o) handler;
  _Adapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);

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

Map<String, dynamic> _feedItem(int postId) => {
  'feed_id': postId,
  'target_type': 'POST',
  'target_id': postId,
  'action_type': 'CREATED_POST',
  'content': {'content': 'bài $postId'},
  'created_at': '2026-10-01T00:00:00Z',
};

void main() {
  late LocalStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorage(await SharedPreferences.getInstance());
  });

  ApiClient clientFor(ResponseBody Function(RequestOptions o) handler) =>
      ApiClient(
        tokens: _Tokens(),
        events: SessionEvents(),
        baseUrl: 'https://example.com/api/v1',
        adapter: _Adapter(handler),
      );

  test('delete: 404 is treated as already deleted and remembered', () async {
    final repo = PostRepository(
      clientFor(
        (o) => _json(404, {'code': '4040', 'message': 'Post not found'}),
      ),
      storage,
    );

    final deletedNow = await repo.delete(42);

    expect(deletedNow, false);
    expect(storage.deletedPostIds, {42});
  });

  test('delete: success is remembered and reported as deleted now', () async {
    final repo = PostRepository(
      clientFor((o) => _json(200, {'code': '0000', 'message': 'ok'})),
      storage,
    );

    expect(await repo.delete(7), true);
    expect(storage.deletedPostIds, {7});
  });

  test('delete: other errors are still thrown and not remembered', () async {
    final repo = PostRepository(
      clientFor((o) => _json(403, {'code': '4030', 'message': 'Forbidden'})),
      storage,
    );

    await expectLater(repo.delete(9), throwsA(isA<ApiException>()));
    expect(storage.deletedPostIds, isEmpty);
  });

  test('feed hides posts that were deleted, keeps the rest', () async {
    await storage.addDeletedPostId(2);
    final repo = FeedRepository(
      clientFor(
        (o) => _json(200, {
          'code': '0000',
          'message': 'ok',
          'data': {
            'items': [_feedItem(1), _feedItem(2), _feedItem(3)],
            'pagination': {'after': null, 'has_next': false},
          },
        }),
      ),
      storage,
    );

    final page = await repo.getFeed();
    expect(page.items.map((i) => i.postId), [1, 3]);

    // Cache trang chủ cũng không hiện lại bài đã xoá
    expect(repo.cachedFirstPage?.items.map((i) => i.postId), [1, 3]);
  });

  test('deleted post ids are capped to the most recent 500', () async {
    for (var i = 0; i < 520; i++) {
      await storage.addDeletedPostId(i);
    }
    final ids = storage.deletedPostIds;
    expect(ids.length, 500);
    expect(ids.contains(519), true);
    expect(ids.contains(0), false);
  });
}
