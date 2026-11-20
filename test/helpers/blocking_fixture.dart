import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/session_events.dart';
import 'package:quizhub/core/services/blocked_users.dart';
import 'package:quizhub/core/storage/credential_storage.dart';
import 'package:quizhub/core/storage/local_storage.dart';
import 'package:quizhub/data/models/saved_account.dart';
import 'package:quizhub/data/repositories/chat_repository.dart';
import 'package:quizhub/data/repositories/feed_repository.dart';
import 'package:quizhub/data/repositories/friend_repository.dart';
import 'package:quizhub/data/repositories/notification_repository.dart';
import 'package:quizhub/data/repositories/post_repository.dart';
import 'package:quizhub/data/repositories/user_repository.dart';
import 'package:quizhub/data/repositories/user_search_repository.dart';
import 'package:quizhub/dev/preview_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> blockingUser(int id) => {
  'user_id': id,
  'full_name': id == 1
      ? 'Tôi'
      : id == 2
      ? 'Lan'
      : 'Minh',
  'email': 'user$id@sis.hust.edu.vn',
  'student_lecturer_code': '2023000$id',
  'profile_completed': true,
  'role': 'STUDENT',
};

Map<String, dynamic> blockingPost(int id, int owner) => {
  'post_id': id,
  'content': 'Nội dung bài $id',
  'author': blockingUser(owner),
  'visibility': 'PUBLIC',
  'created_at': '2026-11-01T00:00:00Z',
};

Map<String, dynamic> blockingPage(List<dynamic> items) => {
  'items': items,
  'pagination': {'has_next': false, 'after': null},
};

/// Cố tình trả cả dữ liệu đã chặn: kiểm tra FE vẫn chặn được dữ liệu cũ/lọt từ API.
class UnfilteredSocialApi implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final blocked = <int>{};
  bool rejectBlock = false;
  Future<Map<String, dynamic>> Function(RequestOptions)? blocksPage;

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    requests.add(o);
    final p = o.path;
    dynamic data;
    if (p.startsWith('/blocks/')) {
      if (o.method == 'POST') {
        if (rejectBlock) return jsonResponse(null, status: 500);
        blocked.add(int.parse(p.split('/').last));
      } else if (o.method == 'DELETE') {
        blocked.remove(int.parse(p.split('/').last));
      }
    } else if (p == '/blocks') {
      data = blocksPage == null
          ? blockingPage([for (final id in blocked) blockingUser(id)])
          : await blocksPage!(o);
    } else if (p == '/users/me') {
      data = blockingUser(1);
    } else if (RegExp(r'^/users/\d+/relationship-stats$').hasMatch(p)) {
      final id = int.parse(p.split('/')[2]);
      data = {
        'relationship_with_me': {'blocked': blocked.contains(id)},
      };
    } else if (RegExp(r'^/users/\d+/posts$').hasMatch(p)) {
      final id = int.parse(p.split('/')[2]);
      data = blockingPage([blockingPost(id == 2 ? 11 : 13, id)]);
    } else if (RegExp(r'^/users/\d+$').hasMatch(p)) {
      data = blockingUser(int.parse(p.split('/').last));
    } else if (p == '/posts/11' || p == '/posts/13') {
      data = blockingPost(p.endsWith('11') ? 11 : 13, p.endsWith('11') ? 2 : 3);
    } else if (p == '/activity-feeds') {
      data = blockingPage([
        for (final owner in [2, 3])
          {
            'feed_id': owner,
            'target_type': 'POST',
            'target_id': owner == 2 ? 11 : 13,
            'actor': blockingUser(owner),
            'content': blockingPost(owner == 2 ? 11 : 13, owner),
          },
        {
          'feed_id': 9,
          'target_type': 'BADGE',
          'target_id': 1,
          'actor': blockingUser(2),
        },
      ]);
    } else if (p == '/search') {
      data = {
        ...blockingPage([
          for (final id in [2, 3]) {'user': blockingUser(id)},
        ]),
        'total_hits': 2,
      };
    } else if (p == '/friendships') {
      data = blockingPage([blockingUser(2), blockingUser(3)]);
    } else if (p == '/friendships/requests/received') {
      data = blockingPage([
        for (final id in [2, 3]) {'requester': blockingUser(id)},
      ]);
    } else if (p == '/friendships/requests/sent') {
      data = blockingPage([
        for (final id in [2, 3]) {'receiver': blockingUser(id)},
      ]);
    } else if (p.startsWith('/follows/')) {
      data = blockingPage([blockingUser(2), blockingUser(3)]);
    } else if (p == '/conversations') {
      data = blockingPage([
        for (final id in [1, 2])
          {
            'conversation_id': id,
            'type': 'DIRECT',
            'display_name': id == 1 ? 'Lan' : 'Minh',
            'last_message': {'message_id': id, 'content': 'Tin riêng $id'},
          },
      ]);
    } else if (p == '/conversations/direct') {
      final peer = (o.data as Map)['target_user_id'] as int;
      data = {
        'conversation_id': peer - 1,
        'type': 'DIRECT',
        'members': [blockingUser(1), blockingUser(peer)],
      };
    } else if (p.endsWith('/members')) {
      final id = int.parse(p.split('/')[2]);
      data = [blockingUser(1), blockingUser(id + 1)];
    } else if (p.endsWith('/messages')) {
      final id = int.parse(p.split('/')[2]);
      data = {
        'conversation_id': id,
        'messages': [
          {'message_id': id, 'sender_id': id + 1, 'content': 'Tin riêng $id'},
        ],
        'pagination': {'has_next': false},
      };
    }
    return jsonResponse(data);
  }

  static ResponseBody jsonResponse(dynamic data, {int status = 200}) =>
      ResponseBody.fromString(
        jsonEncode({
          'code': status == 200 ? '0000' : '1001',
          'message': status == 200 ? 'OK' : 'Thao tác thất bại',
          'data': data,
        }),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
  @override
  void close({bool force = false}) {}
}

class _Credentials extends CredentialStorage {
  @override
  Future<SavedAccount?> read() async => null;
}

class BlockingFixture {
  final SharedPreferences preferences;
  final LocalStorage storage;
  final BlockedUsers blocks;
  final SessionEvents events;
  final ApiClient api;
  late final friends = FriendRepository(api, blocks: blocks);
  late final feed = FeedRepository(api, storage, blocks: blocks);
  late final posts = PostRepository(api, storage, blocks: blocks);
  late final users = UserRepository(
    api,
    storage,
    _Credentials(),
    blocks: blocks,
  );
  late final search = UserSearchRepository(api, friends, blocks: blocks);
  late final chat = ChatRepository(api, blocks: blocks);
  late final notifications = NotificationRepository(api);
  BlockingFixture._(
    this.preferences,
    this.storage,
    this.blocks,
    this.events,
    this.api,
  );

  static Future<BlockingFixture> create({HttpClientAdapter? adapter}) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = LocalStorage(preferences);
    await storage.setCachedUser(blockingUser(1));
    final blocks = BlockedUsers(storage, scope: 'test');
    final events = SessionEvents();
    final api = ApiClient(
      tokens: PreviewTokens(),
      events: events,
      baseUrl: 'https://example.test/api/v1',
      adapter: adapter ?? UnfilteredSocialApi(),
    );
    return BlockingFixture._(preferences, storage, blocks, events, api);
  }

  Future<void> dispose() async {
    blocks.dispose();
    events.dispose();
  }
}
