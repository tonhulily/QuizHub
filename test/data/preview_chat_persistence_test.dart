import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/session_events.dart';
import 'package:quizhub/data/models/chat_models.dart';
import 'package:quizhub/data/repositories/chat_repository.dart';
import 'package:quizhub/dev/preview_backend.dart';
import 'package:quizhub/features/chat/cubit/chat_detail_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingPreferences implements SharedPreferences {
  final bool throwOnSave;
  final _cache = <String, Object>{};
  bool failWrites = false;

  _FailingPreferences({required this.throwOnSave});

  @override
  Object? get(String key) => _cache[key];
  @override
  String? getString(String key) => _cache[key] as String?;
  @override
  List<String>? getStringList(String key) => _cache[key] as List<String>?;
  @override
  Set<String> getKeys() => _cache.keys.toSet();
  @override
  Future<bool> setString(String key, String value) async {
    // SharedPreferences cập nhật cache trước khi biết kết quả ghi platform.
    _cache[key] = value;
    if (!failWrites) return true;
    if (throwOnSave) throw StateError('disk write failed');
    return false;
  }

  @override
  Future<bool> remove(String key) async {
    _cache.remove(key);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedPreferences extends _FailingPreferences {
  Completer<void>? gate;
  final saveStarted = Completer<void>();

  _DelayedPreferences() : super(throwOnSave: false);

  @override
  Future<bool> setString(String key, String value) async {
    final pending = gate;
    if (pending != null) {
      if (!saveStarted.isCompleted) saveStarted.complete();
      await pending.future;
    }
    return super.setString(key, value);
  }
}

class _PreviewSession {
  final SessionEvents events = SessionEvents();
  final PreviewBackend backend;
  late final ChatRepository repo = ChatRepository(
    ApiClient(
      tokens: PreviewTokens(),
      events: events,
      baseUrl: 'https://example.test/api/v1',
      adapter: backend,
    ),
  );
  final cubits = <ChatDetailCubit>[];
  bool _closed = false;

  _PreviewSession({SharedPreferences? preferences})
    : backend = PreviewBackend(preferences: preferences);

  Future<ChatDetailCubit> open({
    int userId = 2,
    ChatConversation? conversation,
  }) async {
    final target = conversation ?? await repo.direct(userId, myId: 1);
    final cubit = ChatDetailCubit(
      repo,
      target: ChatTarget.conversation(target),
      myId: 1,
      realtime: backend.chat.realtime,
      confirmationTimeout: const Duration(milliseconds: 300),
    );
    cubits.add(cubit);
    await cubit.load();
    return cubit;
  }

  Future<ChatMessage> send(String content, {int userId = 2}) async {
    final cubit = await open(userId: userId);
    expect(await cubit.send(content), isNull);
    final message = cubit.state.messages.singleWhere(
      (m) => m.senderId == 1 && m.content == content,
    );
    // Huỷ phản hồi bot để các ca chỉ kiểm tra tin được người dùng xác nhận.
    await cubit.close();
    return message;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final cubit in cubits) {
      if (!cubit.isClosed) await cubit.close();
    }
    await backend.chat.realtime.dispose();
    events.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences preferences;
  late _PreviewSession session;
  final sessions = <_PreviewSession>[];

  _PreviewSession connect({SharedPreferences? store, bool persistent = true}) {
    final result = _PreviewSession(
      preferences: persistent ? store ?? preferences : null,
    );
    sessions.add(result);
    return result;
  }

  Future<void> restart() async {
    await session.close();
    final disk = <String, Object>{
      for (final key in preferences.getKeys()) key: preferences.get(key)!,
    };
    SharedPreferences.setMockInitialValues(disk);
    preferences = await SharedPreferences.getInstance();
    session = connect();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    session = connect();
  });
  tearDown(() async {
    for (final entry in sessions) {
      await entry.close();
    }
    sessions.clear();
  });

  test(
    'gửi chữ và ảnh rồi rời/mở lại chat trong cùng phiên vẫn còn tin',
    () async {
      const image = 'https://example.test/sent-image.jpg';
      final first = await session.open();
      expect(await first.send('Tin chữ cần giữ'), isNull);
      expect(
        await first.send(
          'Ảnh cần giữ',
          messageType: 'IMAGE',
          mediaUrls: [image],
        ),
        isNull,
      );
      final sent = first.state.messages
          .where(
            (m) =>
                m.senderId == 1 &&
                ['Tin chữ cần giữ', 'Ảnh cần giữ'].contains(m.content),
          )
          .toList();
      expect(sent, hasLength(2));
      await first.close();

      final reopened = await session.open();
      for (final message in sent) {
        expect(reopened.state.messages, contains(message));
      }
      final restoredImage = reopened.state.messages.singleWhere(
        (m) => m.content == 'Ảnh cần giữ',
      );
      expect(restoredImage.messageType, 'IMAGE');
      expect(restoredImage.mediaUrls, [image]);
    },
  );

  test('chỉ echo xác nhận gửi sau khi ghi bộ nhớ hoàn tất', () async {
    await session.close();
    final delayed = _DelayedPreferences();
    preferences = delayed;
    session = connect();
    final cubit = await session.open();
    final gate = Completer<void>();
    delayed.gate = gate;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    var completed = false;
    final sending = cubit.send('Đợi lưu xong mới xác nhận').then((result) {
      completed = true;
      return result;
    });
    await delayed.saveStarted.future.timeout(const Duration(seconds: 2));
    expect(completed, isFalse);
    expect(cubit.state.sending, isTrue);
    expect(
      cubit.state.messages.any((m) => m.content == 'Đợi lưu xong mới xác nhận'),
      isFalse,
    );
    gate.complete();
    expect(await sending, isNull);
    final saved = cubit.state.messages.singleWhere(
      (m) => m.content == 'Đợi lưu xong mới xác nhận',
    );
    await cubit.close();
    await restart();
    expect((await session.repo.messages(1)).items, contains(saved));
  });

  test(
    'mở app mới giữ hội thoại, tin nhắn, cursor và không cấp trùng ID',
    () async {
      final onSeededChat = await session.send('Giữ lịch sử có phân trang');
      final newConversation = await session.repo.direct(5, myId: 1);
      final onNewChat = await session.send('Giữ hội thoại mới', userId: 5);
      await restart();

      expect(
        (await session.repo.direct(5, myId: 1)).conversationId,
        newConversation.conversationId,
      );
      expect(
        (await session.repo.conversations()).items.map((c) => c.conversationId),
        contains(newConversation.conversationId),
      );
      expect(
        (await session.repo.messages(newConversation.conversationId)).items,
        contains(onNewChat),
      );
      final first = await session.repo.messages(onSeededChat.conversationId);
      expect(first.items, hasLength(20));
      expect(first.hasNext, isTrue);
      final second = await session.repo.messages(
        onSeededChat.conversationId,
        after: first.after,
      );
      expect(second.items, hasLength(6));
      expect(second.hasNext, isFalse);
      final all = [...first.items, ...second.items];
      expect(all, contains(onSeededChat));
      expect(all.map((m) => m.messageId).toSet(), hasLength(26));
      final next = await session.send('Tin sau lần mở app mới', userId: 5);
      expect(next.messageId, greaterThan(onNewChat.messageId));
    },
  );

  test('ảnh đã gửi còn đủ loại và URL sau khi dựng lại app', () async {
    final cubit = await session.open();
    expect(
      await cubit.send(
        'Ảnh sau restart',
        messageType: 'IMAGE',
        mediaUrls: ['https://example.test/photo.jpg'],
      ),
      isNull,
    );
    final saved = cubit.state.messages.singleWhere(
      (m) => m.content == 'Ảnh sau restart',
    );
    await cubit.close();
    await restart();
    expect(
      (await session.repo.messages(saved.conversationId)).items,
      contains(saved),
    );
  });

  test(
    'xoá/thu hồi vẫn giữ sau restart và ID tin đã xoá không cấp lại',
    () async {
      final removed = await session.send('Tin xoá riêng');
      final revoked = await session.send('Tin thu hồi');
      final hiddenRevoked = await session.send('Tin thu hồi rồi xoá riêng');
      await session.repo.deleteMessage(removed.messageId);
      await session.repo.deleteMessage(revoked.messageId, forEveryone: true);
      await session.repo.deleteMessage(
        hiddenRevoked.messageId,
        forEveryone: true,
      );
      await session.repo.deleteMessage(hiddenRevoked.messageId);
      await restart();

      final history = await session.repo.messages(removed.conversationId);
      expect(
        history.items.any((m) => m.messageId == removed.messageId),
        isFalse,
      );
      final restored = history.items.singleWhere(
        (m) => m.messageId == revoked.messageId,
      );
      expect(restored.revoked, isTrue);
      expect(restored.content, isEmpty);
      expect(
        history.items.any((m) => m.messageId == hiddenRevoked.messageId),
        isFalse,
      );
      final next = await session.send('Tin sau khi xoá');
      expect(next.messageId, greaterThan(hiddenRevoked.messageId));
    },
  );

  for (final throwOnSave in [false, true]) {
    test(
      'lỗi ghi ($throwOnSave) không echo thành công hoặc khôi phục tin ma',
      () async {
        final broken = _FailingPreferences(throwOnSave: throwOnSave);
        final current = connect(store: broken);
        final cubit = await current.open();
        final conversation = cubit.state.conversation!;
        final before = (await current.repo.messages(
          conversation.conversationId,
        )).items;
        broken.failWrites = true;
        final error = await cubit.send('Không được báo đã gửi');
        expect(error, isNotNull);
        expect(
          cubit.state.messages.any((m) => m.content == 'Không được báo đã gửi'),
          isFalse,
        );
        expect(
          (await current.repo.messages(conversation.conversationId)).items,
          before,
        );
        await current.close();
        final reopened = connect(store: broken);
        final restored = await reopened.open(conversation: conversation);
        expect(
          restored.state.messages.any(
            (m) => m.content == 'Không được báo đã gửi',
          ),
          isFalse,
        );
      },
    );
  }

  for (final raw in ['not json', '{"version":1,"conversations":[{}]}']) {
    test(
      'cache chat hỏng không làm crash và lần lưu sau dùng lại được: $raw',
      () async {
        await session.close();
        SharedPreferences.setMockInitialValues({'preview_chat_v1_1': raw});
        preferences = await SharedPreferences.getInstance();
        session = connect();
        expect((await session.repo.messages(1)).items, hasLength(20));
        final saved = await session.send('Tin sau dữ liệu hỏng');
        await restart();
        expect((await session.repo.messages(1)).items, contains(saved));
      },
    );
  }

  test(
    'fixture không truyền preferences vẫn độc lập giữa các lần tạo',
    () async {
      final first = connect(persistent: false);
      await first.send('Chỉ trong fixture thứ nhất');
      await first.close();
      final second = connect(persistent: false);
      expect(
        (await second.repo.messages(
          1,
        )).items.any((m) => m.content == 'Chỉ trong fixture thứ nhất'),
        isFalse,
      );
    },
  );
}
