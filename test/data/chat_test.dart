import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/session_events.dart';
import 'package:quizhub/data/models/chat_models.dart';
import 'package:quizhub/data/repositories/chat_repository.dart';
import 'package:quizhub/dev/preview_backend.dart';
import 'package:quizhub/features/chat/cubit/chat_detail_cubit.dart';

void main() {
  late ChatRepository repo;
  late SessionEvents events;
  setUp(() {
    events = SessionEvents();
    repo = ChatRepository(
      ApiClient(
        tokens: PreviewTokens(),
        events: events,
        adapter: PreviewBackend(),
      ),
    );
  });
  tearDown(() => events.dispose());

  test(
    'chat trực tiếp lặp lại trả cùng id và chọn đúng người đối diện',
    () async {
      final first = await repo.direct(2, myId: 1);
      final second = await repo.direct(2, myId: 1);
      expect(second.conversationId, first.conversationId);
      expect(first.peer(1)!.userId, 2);
      expect(first.title, 'Trần Thị Lan');
    },
  );

  test('đọc lịch sử từ messages, cursor và id hội thoại được giữ', () async {
    final conversation = (await repo.conversations()).items.first;
    final first = await repo.messages(conversation.conversationId);
    expect(first.items, hasLength(20));
    expect(first.hasNext, isTrue);
    expect(
      first.items.every((m) => m.conversationId == conversation.conversationId),
      isTrue,
    );
    final second = await repo.messages(
      conversation.conversationId,
      after: first.after,
    );
    expect(second.items, hasLength(5));
    expect(second.hasNext, isFalse);
    expect(
      first.items
          .map((m) => m.messageId)
          .toSet()
          .intersection(second.items.map((m) => m.messageId).toSet()),
      isEmpty,
    );
  });

  test('xoá riêng và thu hồi trả lịch sử đúng', () async {
    final page = await repo.messages(1);
    final own = page.items.firstWhere((m) => m.senderId == 1);
    await repo.deleteMessage(own.messageId, forEveryone: true);
    expect(
      (await repo.messages(
        1,
      )).items.firstWhere((m) => m.messageId == own.messageId).revoked,
      isTrue,
    );
    await repo.deleteMessage(own.messageId);
    expect(
      (await repo.messages(1)).items.any((m) => m.messageId == own.messageId),
      isFalse,
    );
  });

  test('tải thêm rồi làm mới giữ tin cũ, thứ tự và không nhân đôi', () async {
    final conversation = await repo.direct(2, myId: 1);
    final cubit = ChatDetailCubit(
      repo,
      target: ChatTarget.conversation(conversation),
      myId: 1,
    );
    await cubit.load();
    await cubit.loadMore();
    expect(cubit.state.messages, hasLength(25));
    await cubit.load();
    expect(cubit.state.messages, hasLength(25));
    expect(cubit.state.messages.map((m) => m.messageId).toSet(), hasLength(25));
    expect(
      cubit.state.messages.first.messageId,
      greaterThan(cubit.state.messages.last.messageId),
    );
    await cubit.close();
  });

  test('rời màn trước khi API hoàn tất không emit vào cubit đã đóng', () async {
    final cubit = ChatDetailCubit(
      repo,
      target: const ChatTarget.conversation(
        ChatConversation(conversationId: 1, title: 'Bạn A'),
      ),
      myId: 1,
    );
    final loading = cubit.load();
    await cubit.close();
    await expectLater(loading, completes);
  });
}
