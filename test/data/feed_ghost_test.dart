import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/session_events.dart';
import 'package:quizhub/core/storage/local_storage.dart';
import 'package:quizhub/core/storage/token_storage.dart';
import 'package:quizhub/data/models/feed_item.dart';
import 'package:quizhub/data/repositories/feed_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Adapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions o) handler;
  final List<String> paths = [];
  _Adapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    return handler(options);
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

Map<String, dynamic> _item(int postId, int actorId) => {
  'feed_id': postId,
  'target_type': 'POST',
  'target_id': postId,
  'action_type': 'CREATED_POST',
  'actor': {'user_id': actorId, 'full_name': 'User $actorId'},
  'content': {'title': 'bài $postId', 'media_url': 'https://x/$postId.jpg'},
  'created_at': '2026-10-18T09:00:00Z',
};

void main() {
  test('feed snapshot {title, media_url} is shown as text + image', () {
    final item = FeedItem.fromJson({
      ..._item(5, 325),
      'content': {'title': 'Abc', 'media_url': 'https://x/a.jpg'},
    });

    final post = item.toPost()!;
    expect(post.content, 'Abc');
    expect(post.media.length, 1);
    expect(post.media.first.url, 'https://x/a.jpg');
    expect(post.media.first.isVideo, false);
  });

  test('feed snapshot with video url and empty title', () {
    final item = FeedItem.fromJson({
      ..._item(6, 325),
      'content': {'title': '', 'media_url': 'https://x/v.mp4?sig=1'},
    });

    final post = item.toPost()!;
    expect(post.content, '');
    expect(post.media.single.isVideo, true);
  });

  test('full post content is not overwritten by the snapshot mapping', () {
    final item = FeedItem.fromJson({
      ..._item(7, 325),
      'content': {
        'content': 'Nội dung đầy đủ',
        'title': 'Tiêu đề',
        'media_urls': [
          {'url': 'https://x/1.jpg', 'type': 'IMAGE'},
        ],
      },
    });

    final post = item.toPost()!;
    expect(post.content, 'Nội dung đầy đủ');
    expect(post.media.single.url, 'https://x/1.jpg');
  });

  group('FeedRepository removes ghosts of my own deleted posts', () {
    late LocalStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorage(await SharedPreferences.getInstance());
      await storage.setCachedUser({'user_id': 325});
    });

    FeedRepository repoWith(_Adapter adapter) => FeedRepository(
      ApiClient(
        tokens: _Tokens(),
        events: SessionEvents(),
        baseUrl: 'https://example.com/api/v1',
        adapter: adapter,
      ),
      storage,
    );

    test('404 on my post hides it and remembers the id', () async {
      final adapter = _Adapter((o) {
        if (o.path == '/activity-feeds') {
          return _json(200, {
            'code': '0000',
            'message': 'ok',
            'data': {
              'items': [
                _item(2, 325), // của mình, đã xoá (404)
                _item(3, 325), // của mình, còn tồn tại
                _item(4, 99), // của người khác -> không cần kiểm tra
              ],
              'pagination': {'after': null, 'has_next': false},
            },
          });
        }
        if (o.path == '/posts/2') {
          return _json(404, {'code': '4040', 'message': 'Post not found'});
        }
        return _json(200, {'code': '0000', 'message': 'ok', 'data': null});
      });

      final page = await repoWith(adapter).getFeed();

      expect(page.items.map((i) => i.postId), [3, 4]);
      expect(storage.deletedPostIds, {2});
      // Chỉ kiểm tra bài của mình, không gọi /posts/4 của người khác
      expect(adapter.paths, containsAll(['/posts/2', '/posts/3']));
      expect(adapter.paths, isNot(contains('/posts/4')));
    });

    test('network failure keeps the post (no false deletion)', () async {
      final adapter = _Adapter((o) {
        if (o.path == '/activity-feeds') {
          return _json(200, {
            'code': '0000',
            'message': 'ok',
            'data': {
              'items': [_item(2, 325)],
              'pagination': {'after': null, 'has_next': false},
            },
          });
        }
        return _json(500, {'code': '5000', 'message': 'boom'});
      });

      final page = await repoWith(adapter).getFeed();

      expect(page.items.map((i) => i.postId), [2]);
      expect(storage.deletedPostIds, isEmpty);
    });
  });
}
