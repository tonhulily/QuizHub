import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/api_exception.dart';
import 'package:quizhub/core/network/session_events.dart';
import 'package:quizhub/core/services/chat_realtime.dart';
import 'package:quizhub/core/storage/token_storage.dart';
import 'package:quizhub/data/models/chat_models.dart';
import 'package:quizhub/data/repositories/chat_repository.dart';
import 'package:quizhub/data/repositories/media_repository.dart';
import 'package:quizhub/dev/preview_backend.dart';
import 'package:quizhub/features/chat/cubit/chat_detail_cubit.dart';
import '../../tool/chat_demo_server.dart';

class _Tokens extends TokenStorage {
  final int id;
  _Tokens(this.id);
  @override
  String get accessToken => 'chat-demo-$id';
  @override
  String get refreshToken => 'chat-demo-refresh-$id';
  @override
  bool get hasTokens => true;
  @override
  Future<void> load() async {}
}

class _Client {
  final int id;
  final SessionEvents sessions = SessionEvents();
  late final tokens = _Tokens(id);
  late final ApiClient api;
  late final ChatRepository repo;
  late final StompChatRealtime live;
  final events = <ChatEvent>[];
  late final StreamSubscription<ChatEvent> subscription;
  _Client(this.id, String baseUrl) {
    api = ApiClient(tokens: tokens, events: sessions, baseUrl: baseUrl);
    repo = ChatRepository(api);
    live = StompChatRealtime(
      api,
      tokens,
      sessions,
      url: '${baseUrl.replaceFirst('http', 'ws')}/ws/websocket',
      retryBase: const Duration(milliseconds: 30),
    );
    subscription = live.events.listen(events.add);
  }
  Future<void> connect() async {
    await live.acquire();
    await _until(() => live.connection == ChatConnection.connected);
  }

  Future<void> close() async {
    await live.dispose();
    await subscription.cancel();
    sessions.dispose();
  }
}

Future<void> _until(bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(
    ready(),
    isTrue,
    reason: 'Không nhận được dữ liệu từ phiên chat còn lại',
  );
}

void main() {
  late Directory directory;
  late ChatDemoServer server;
  final clients = <_Client>[];
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('quizhub-shared-chat-');
    server = await ChatDemoServer.start(dataDirectory: directory);
  });
  tearDown(() async {
    for (final client in clients) {
      await client.close();
    }
    clients.clear();
    await server.close();
    await directory.delete(recursive: true);
  });
  _Client client(int id) {
    final c = _Client(id, server.baseUrl);
    clients.add(c);
    return c;
  }

  Future<void> restart() async {
    for (final c in clients) {
      await c.close();
    }
    clients.clear();
    final port = server.port;
    await server.close();
    server = await ChatDemoServer.start(dataDirectory: directory, port: port);
  }

  test(
    'hai tài khoản nhận tin STOMP hai chiều, không bot; mở lại server còn tin',
    () async {
      final an = client(1);
      final lan = client(2);
      await Future.wait([an.connect(), lan.connect()]);
      final aConv = await an.repo.direct(2, myId: 1);
      final bConv = await lan.repo.direct(1, myId: 2);
      expect(aConv.conversationId, bConv.conversationId);
      expect(aConv.peer(1)?.userId, 2);
      expect(bConv.peer(2)?.userId, 1);
      final a = ChatDetailCubit(
        an.repo,
        target: ChatTarget.conversation(aConv),
        myId: 1,
        realtime: an.live,
      );
      final b = ChatDetailCubit(
        lan.repo,
        target: ChatTarget.conversation(bConv),
        myId: 2,
        realtime: lan.live,
      );
      try {
        await Future.wait([a.load(), b.load()]);
        await _until(() => a.state.accessVerified && b.state.accessVerified);
        expect(await a.send('An gửi sang Lan'), isNull);
        await _until(
          () => b.state.messages.any((m) => m.content == 'An gửi sang Lan'),
        );
        await Future<void>.delayed(const Duration(milliseconds: 1400));
        expect(
          (await an.repo.messages(aConv.conversationId)).items,
          hasLength(1),
        );
        expect(await b.send('Lan nhắn lại An'), isNull);
        await _until(
          () => a.state.messages.any((m) => m.content == 'Lan nhắn lại An'),
        );
      } finally {
        await a.close();
        await b.close();
      }
      await restart();
      final restoredA = client(1);
      final restoredB = client(2);
      final restored = await restoredA.repo.direct(2, myId: 1);
      expect(restored.conversationId, aConv.conversationId);
      for (final c in [restoredA, restoredB]) {
        final history = await c.repo.messages(restored.conversationId);
        expect(
          history.items.map((m) => m.content),
          containsAll(['An gửi sang Lan', 'Lan nhắn lại An']),
        );
        expect(history.items, hasLength(2));
      }
    },
  );

  test('typing, số chưa đọc và đã đọc phản ánh tài khoản còn lại', () async {
    final an = client(1);
    final lan = client(2);
    await Future.wait([an.connect(), lan.connect()]);
    final conv = await an.repo.direct(2, myId: 1);
    final unwatch = an.live.watchTyping(conv.conversationId);
    addTearDown(unwatch);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    lan.live.typing(conv.conversationId, true);
    await _until(
      () => an.events.any(
        (e) => e.kind == ChatEventKind.typing && e.userId == 2 && e.isTyping,
      ),
    );
    an.live.send(conversationId: conv.conversationId, content: 'Tin chưa đọc');
    await _until(
      () => lan.events.any((e) => e.message?.content == 'Tin chưa đọc'),
    );
    expect((await lan.repo.conversations()).items.single.unreadCount, 1);
    final messages = await lan.repo.messages(conv.conversationId);
    await _until(
      () => an.events.any(
        (e) =>
            e.kind == ChatEventKind.read &&
            e.userId == 2 &&
            e.readMessageId == messages.items.single.messageId,
      ),
    );
    expect((await lan.repo.conversations()).items.single.unreadCount, 0);
  });

  test('xoá phía mình, thu hồi và ảnh được giữ đúng qua restart', () async {
    final an = client(1);
    final lan = client(2);
    await Future.wait([an.connect(), lan.connect()]);
    final conv = await an.repo.direct(2, myId: 1);
    final png = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aJxkAAAAASUVORK5CYII=',
      ),
    );
    final image = await MediaRepository(
      an.api,
    ).uploadImageBytes(png, name: 'test.png', purpose: MediaPurpose.chat);
    final bytes = await Dio().get<List<int>>(
      image.url,
      options: Options(responseType: ResponseType.bytes),
    );
    expect(bytes.data, png);
    an.live.send(
      conversationId: conv.conversationId,
      content: 'Ảnh gửi cho Lan',
      messageType: 'IMAGE',
      mediaUrls: [image.url],
    );
    await _until(
      () => lan.events.any(
        (e) => e.message?.mediaUrls.contains(image.url) ?? false,
      ),
    );
    final picture = (await an.repo.messages(conv.conversationId)).items.single;
    an.live.send(
      conversationId: conv.conversationId,
      content: 'Thu hồi nội dung này',
    );
    await _until(
      () => lan.events.any((e) => e.message?.content == 'Thu hồi nội dung này'),
    );
    final revoked = (await an.repo.messages(conv.conversationId)).items.first;
    await an.repo.deleteMessage(revoked.messageId, forEveryone: true);
    await an.repo.deleteMessage(picture.messageId);
    await restart();
    final a = client(1);
    final b = client(2);
    final own = await a.repo.messages(conv.conversationId);
    final peer = await b.repo.messages(conv.conversationId);
    expect(own.items.any((m) => m.messageId == picture.messageId), isFalse);
    expect(
      peer.items.firstWhere((m) => m.messageId == picture.messageId).mediaUrls,
      [image.url],
    );
    final removed = peer.items.firstWhere(
      (m) => m.messageId == revoked.messageId,
    );
    expect(removed.revoked, isTrue);
    expect(removed.content, isEmpty);
    expect(removed.mediaUrls, isEmpty);
    final retainedImage = await Dio().get<List<int>>(
      image.url,
      options: Options(responseType: ResponseType.bytes),
    );
    expect(retainedImage.data, png);
  });

  for (final deletingUser in [1, 2]) {
    test(
      'người $deletingUser xoá khối thu hồi chỉ mất phía mình, giữ đúng sau restart',
      () async {
        final an = client(1);
        final lan = client(2);
        await Future.wait([an.connect(), lan.connect()]);
        final conv = await an.repo.direct(2, myId: 1);
        an.live.send(
          conversationId: conv.conversationId,
          content: 'Thu hồi rồi xoá riêng',
        );
        await _until(
          () => lan.events.any(
            (e) => e.message?.content == 'Thu hồi rồi xoá riêng',
          ),
        );
        final message = (await an.repo.messages(
          conv.conversationId,
        )).items.single;
        await an.repo.deleteMessage(message.messageId, forEveryone: true);
        for (final c in [an, lan]) {
          expect(
            (await c.repo.messages(conv.conversationId)).items.single.revoked,
            isTrue,
          );
        }

        final deleting = deletingUser == 1 ? an : lan;
        final other = deletingUser == 1 ? lan : an;
        await deleting.repo.deleteMessage(message.messageId);
        expect(
          (await deleting.repo.messages(conv.conversationId)).items,
          isEmpty,
        );
        final retained = (await other.repo.messages(
          conv.conversationId,
        )).items.single;
        expect(retained.messageId, message.messageId);
        expect(retained.revoked, isTrue);
        expect(retained.content, isEmpty);

        await restart();
        final reopened = client(deletingUser);
        final peer = client(other.id);
        expect(
          (await reopened.repo.messages(conv.conversationId)).items,
          isEmpty,
        );
        expect(
          (await peer.repo.messages(conv.conversationId)).items.single,
          retained,
        );
      },
    );
  }

  test('chặn hai chiều không cho gửi hoặc xem; bỏ chặn giữ lịch sử', () async {
    final an = client(1);
    final lan = client(2);
    await Future.wait([an.connect(), lan.connect()]);
    final conv = await an.repo.direct(2, myId: 1);
    an.live.send(
      conversationId: conv.conversationId,
      content: 'Giữ lại sau bỏ chặn',
    );
    await _until(
      () => lan.events.any((e) => e.message?.content == 'Giữ lại sau bỏ chặn'),
    );
    await an.api.postVoid('/blocks/2');
    expect((await lan.repo.conversations()).items, isEmpty);
    await expectLater(
      lan.repo.messages(conv.conversationId),
      throwsA(isA<ApiException>()),
    );
    lan.live.send(
      conversationId: conv.conversationId,
      content: 'Không được lưu',
    );
    await _until(() => lan.events.any((e) => e.kind == ChatEventKind.error));
    await an.api.deleteVoid('/blocks/2');
    final restored = await lan.repo.messages(conv.conversationId);
    expect(restored.items, hasLength(1));
    expect(restored.items.single.content, 'Giữ lại sau bỏ chặn');
  });

  test('preview độc lập mặc định không tự sinh câu trả lời bot', () async {
    final backend = PreviewBackend();
    final events = SessionEvents();
    final api = ApiClient(
      tokens: PreviewTokens(),
      events: events,
      adapter: backend,
    );
    final repo = ChatRepository(api);
    final conv = await repo.direct(2, myId: 1);
    final cubit = ChatDetailCubit(
      repo,
      target: ChatTarget.conversation(conv),
      myId: 1,
      realtime: backend.chat.realtime,
    );
    addTearDown(() async {
      await cubit.close();
      await backend.chat.realtime.dispose();
      events.dispose();
    });
    await cubit.load();
    final before = (await repo.messages(conv.conversationId)).items.length;
    expect(await cubit.send('Không tự trả lời'), isNull);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final history = await repo.messages(conv.conversationId);
    // Trang đầu chỉ tối đa 20 tin; kiểm tra trực tiếp dữ liệu nguồn để không nhầm phân trang.
    expect(
      backend.chat.messages[conv.conversationId]!.where(
        (m) => m['content'] == 'Mình nhận được rồi nhé!',
      ),
      isEmpty,
    );
    expect(history.items.first.content, 'Không tự trả lời');
    expect(before, 20);
  });

  test('upload ảnh bằng bytes vẫn chặn GIF và ảnh vượt 4MB', () async {
    final an = client(1);
    final media = MediaRepository(an.api);
    await expectLater(
      media.uploadImageBytes(
        Uint8List(4),
        name: 'anh.GIF',
        purpose: MediaPurpose.chat,
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.type,
          'loại lỗi',
          ApiErrorType.validation,
        ),
      ),
    );
    await expectLater(
      media.uploadImageBytes(
        Uint8List(4 * 1024 * 1024 + 1),
        name: 'anh.png',
        purpose: MediaPurpose.chat,
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.type,
          'loại lỗi',
          ApiErrorType.validation,
        ),
      ),
    );
  });
}
