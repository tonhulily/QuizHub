import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/api_exception.dart';
import 'package:quizhub/core/network/session_events.dart';
import 'package:quizhub/data/models/comment_model.dart';
import 'package:quizhub/data/repositories/comment_repository.dart';
import 'package:quizhub/data/repositories/reaction_repository.dart';
import 'package:quizhub/dev/preview_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Capture implements HttpClientAdapter {
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode({
        'code': '0000',
        'data': {'my_reaction': 'LIKE', 'total_count': 1},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FailingPreferences implements SharedPreferences {
  final _cache = <String, Object>{};
  @override
  Object? get(String key) => _cache[key];
  @override
  List<String>? getStringList(String key) => null;
  @override
  Future<bool> setString(String key, String value) async {
    _cache[key] = value;
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences preferences;
  late CommentRepository comments;
  late ReactionRepository reactions;
  final sessions = <SessionEvents>[];

  ApiClient client(HttpClientAdapter adapter) {
    final events = SessionEvents();
    sessions.add(events);
    return ApiClient(
      tokens: PreviewTokens(),
      events: events,
      baseUrl: 'https://example.test/api/v1',
      adapter: adapter,
    );
  }

  void connect() {
    final api = client(PreviewBackend(preferences: preferences));
    comments = CommentRepository(api);
    reactions = ReactionRepository(api);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    connect();
  });
  tearDown(() {
    for (final events in sessions) {
      events.dispose();
    }
    sessions.clear();
  });

  test('reaction request targets COMMENT id, not the parent post', () async {
    final capture = _Capture();
    await ReactionRepository(
      client(capture),
    ).toggleLike(targetType: TargetType.comment, targetId: 202);
    expect(capture.request!.method, 'POST');
    expect(capture.request!.path, '/react');
    expect(capture.request!.data, {
      'target_type': 'COMMENT',
      'target_id': 202,
      'reaction_type': 'LIKE',
    });
  });

  test(
    'preview persists root/reply reaction on reopening sheet and app',
    () async {
      final root = (await comments.list(
        targetType: TargetType.post,
        targetId: 13,
      )).items.first;
      final reply = (await comments.list(
        targetType: TargetType.post,
        targetId: 13,
        parentCommentId: root.commentId,
      )).items.single;
      await reactions.toggleLike(
        targetType: TargetType.comment,
        targetId: root.commentId,
      );
      await reactions.toggleLike(
        targetType: TargetType.comment,
        targetId: reply.commentId,
      );
      final reopened = (await comments.list(
        targetType: TargetType.post,
        targetId: 13,
      )).items.first;
      expect(reopened.reactedByMe, isTrue);
      expect(reopened.reactCount, 1);

      final disk = <String, Object>{
        for (final key in preferences.getKeys()) key: preferences.get(key)!,
      };
      SharedPreferences.setMockInitialValues(disk);
      preferences = await SharedPreferences.getInstance();
      connect();
      final restored = (await comments.list(
        targetType: TargetType.post,
        targetId: 13,
      )).items.first;
      expect(restored.commentId, root.commentId);
      expect(restored.reactedByMe, isTrue);
      expect(restored.reactCount, 1);
      final restoredReply = (await comments.list(
        targetType: TargetType.post,
        targetId: 13,
        parentCommentId: root.commentId,
      )).items.single;
      expect(restoredReply.reactedByMe, isTrue);
      await reactions.toggleLike(
        targetType: TargetType.comment,
        targetId: root.commentId,
      );
      final unliked = (await comments.list(
        targetType: TargetType.post,
        targetId: 13,
      )).items.first;
      expect(unliked.reactedByMe, isFalse);
      expect(unliked.reactCount, 0);
      expect(
        (await comments.list(
          targetType: TargetType.post,
          targetId: 13,
          parentCommentId: root.commentId,
        )).items.single.reactedByMe,
        isTrue,
      );
    },
  );

  test(
    'preview reactions are isolated between posts and question comments',
    () async {
      final a = (await comments.list(
        targetType: TargetType.post,
        targetId: 13,
      )).items.first;
      final b = (await comments.list(
        targetType: TargetType.post,
        targetId: 12,
      )).items.first;
      final q = (await comments.list(
        targetType: TargetType.question,
        targetId: 13,
      )).items.first;
      expect({a.commentId, b.commentId, q.commentId}, hasLength(3));
      await reactions.toggleLike(
        targetType: TargetType.comment,
        targetId: a.commentId,
      );
      expect(
        (await comments.list(
          targetType: TargetType.post,
          targetId: 12,
        )).items.first.reactedByMe,
        isFalse,
      );
      expect(
        (await comments.list(
          targetType: TargetType.question,
          targetId: 13,
        )).items.first.reactedByMe,
        isFalse,
      );
    },
  );

  test(
    'failed preview write rolls back both reaction and local cache',
    () async {
      final store = _FailingPreferences();
      final api = client(PreviewBackend(preferences: store));
      final repo = CommentRepository(api);
      final root = (await repo.list(
        targetType: TargetType.post,
        targetId: 13,
      )).items.first;
      await expectLater(
        ReactionRepository(
          api,
        ).toggleLike(targetType: TargetType.comment, targetId: root.commentId),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 500)),
      );
      expect(
        (await repo.list(
          targetType: TargetType.post,
          targetId: 13,
        )).items.first.reactedByMe,
        isFalse,
      );
      final restarted = CommentRepository(
        client(PreviewBackend(preferences: store)),
      );
      final restored = (await restarted.list(
        targetType: TargetType.post,
        targetId: 13,
      )).items.first;
      expect(restored.reactedByMe, isFalse);
      expect(restored.reactCount, 0);
    },
  );
}
