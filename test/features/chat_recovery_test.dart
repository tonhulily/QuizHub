import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/network/api_exception.dart';
import 'package:quizhub/data/models/chat_models.dart';
import 'package:quizhub/data/models/cursor_page.dart';
import 'package:quizhub/data/repositories/chat_repository.dart';
import 'package:quizhub/features/chat/cubit/chat_detail_cubit.dart';

import '../helpers/chat_fixture.dart';

class _FlakyChat implements ChatRepository {
  final ChatRepository delegate;
  bool failHistory = false;
  bool failAccess = false;
  _FlakyChat(this.delegate);
  static const error = ApiException(
    type: ApiErrorType.noConnection,
    message: 'Mất mạng khi tải chat',
  );
  @override
  Future<CursorPage<ChatMessage>> messages(int id, {String? after}) async {
    if (failHistory) throw error;
    return delegate.messages(id, after: after);
  }

  @override
  Future<bool> blockedWith(int id) async {
    if (failAccess) throw error;
    return delegate.blockedWith(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late ChatFixture f;
  setUp(() => f = ChatFixture());
  tearDown(() => f.dispose());

  test('lỗi tải lịch sử dừng chờ và thử lại khôi phục được chat', () async {
    final repo = _FlakyChat(f.repo)..failHistory = true;
    final conversation = await f.repo.direct(2, myId: 1);
    final cubit = ChatDetailCubit(
      repo,
      target: ChatTarget.conversation(conversation),
      myId: 1,
      realtime: f.data.realtime,
    );
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.status, ChatStatus.failure);
    expect(cubit.state.checkingAccess, isFalse);
    expect(cubit.state.accessVerified, isFalse);
    expect(await cubit.send('Không gửi trước khi xác nhận quyền'), isNotNull);
    repo.failHistory = false;
    await cubit.load();
    expect(cubit.state.status, ChatStatus.loaded);
    expect(cubit.state.accessVerified, isTrue);
    expect(cubit.state.error, isNull);
  });

  test('lỗi kiểm tra quyền không giữ vòng chờ hoặc mở khoá gửi nhầm', () async {
    final repo = _FlakyChat(f.repo)..failAccess = true;
    final conversation = await f.repo.direct(2, myId: 1);
    final cubit = ChatDetailCubit(
      repo,
      target: ChatTarget.conversation(conversation),
      myId: 1,
      realtime: f.data.realtime,
    );
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.checkingAccess, isFalse);
    expect(cubit.state.error?.isNetworkError, isTrue);
    expect(cubit.state.accessVerified, isFalse);
    final before = f.data.messages[1]!.length;
    expect(await cubit.send('Chưa có quyền'), isNotNull);
    expect(f.data.messages[1]!, hasLength(before));
    repo.failAccess = false;
    await cubit.load();
    expect(cubit.state.accessVerified, isTrue);
    expect(await cubit.send('Kết nối lại rồi'), isNull);
  });

  test('đồng bộ lại cập nhật thu hồi ở trang tin cũ đã tải', () async {
    final conversation = await f.repo.direct(2, myId: 1);
    final cubit = ChatDetailCubit(
      f.repo,
      target: ChatTarget.conversation(conversation),
      myId: 1,
    );
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.loadMore();
    expect(cubit.state.messages, hasLength(25));
    final old = f.data.messages[1]!.first;
    final id = old['message_id'];
    old['revoked'] = true;
    old['content'] = '';
    // Có thêm tin mới đẩy con trỏ, vẫn phải cập nhật đủ phần lịch sử đang xem.
    for (var i = 0; i < 22; i++) {
      f.data.append(1, 2, 'Tin mới $i', 'TEXT', []);
    }
    await cubit.load();
    expect(
      cubit.state.messages.firstWhere((m) => m.messageId == id).revoked,
      isTrue,
    );
    expect(cubit.state.messages, hasLength(47));
    expect(cubit.state.messages.map((m) => m.messageId).toSet(), hasLength(47));
    expect(cubit.state.hasNext, isFalse);
  });

  test('tin đã xoá ở phiên khác được gỡ khỏi lịch sử cũ sau đồng bộ', () async {
    final conversation = await f.repo.direct(2, myId: 1);
    final cubit = ChatDetailCubit(
      f.repo,
      target: ChatTarget.conversation(conversation),
      myId: 1,
    );
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.loadMore();
    final id = f.data.messages[1]!.removeAt(1)['message_id'];
    await cubit.load();
    expect(cubit.state.messages.any((m) => m.messageId == id), isFalse);
    expect(cubit.state.messages, hasLength(24));
  });
}
