import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/session_events.dart';
import 'package:quizhub/core/storage/token_storage.dart';
import 'package:quizhub/data/models/social_models.dart';
import 'package:quizhub/data/repositories/friend_repository.dart';

class _Backend implements HttpClientAdapter {
  final dynamic data;
  RequestOptions? request;
  _Backend(this.data);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode({'code': '0000', 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('đọc người dùng từ danh sách phẳng hoặc object quan hệ', () {
    for (final key in [
      null,
      'user',
      'follower',
      'followed_user',
      'blocked_user',
    ]) {
      final user = {
        'user_id': 8,
        'full_name': 'Bạn A',
        'avatar_frame_url': 'frame',
      };
      final model = RelationshipUserModel.fromJson(
        key == null ? user : {key: user},
      );
      expect(model.userId, 8);
      expect(model.fullName, 'Bạn A');
      expect(model.frameUrl, 'frame');
    }
  });

  test('following gửi cursor và giữ thông tin trang tiếp theo', () async {
    final backend = _Backend({
      'items': [
        {'user_id': 8, 'full_name': 'Bạn A'},
      ],
      'pagination': {'after': 8, 'has_next': true},
    });
    final events = SessionEvents();
    final repo = FriendRepository(
      ApiClient(tokens: TokenStorage(), events: events, adapter: backend),
    );
    final page = await repo.following(after: '12', limit: 10);
    expect(backend.request!.path, '/follows/following');
    expect(backend.request!.queryParameters, {'after': '12', 'limit': 10});
    expect(page.items.single.userId, 8);
    expect(page.after, '8');
    expect(page.hasNext, isTrue);
    events.dispose();
  });

  test('lọc id chặn không hợp lệ và đọc người dùng lồng nhau', () async {
    final backend = _Backend({
      'items': [
        {
          'blocked_user': {'user_id': 8},
        },
        {'user_id': 9},
        {},
      ],
    });
    final events = SessionEvents();
    final repo = FriendRepository(
      ApiClient(tokens: TokenStorage(), events: events, adapter: backend),
    );
    expect(await repo.blockedIds(), {8, 9});
    events.dispose();
  });
}
