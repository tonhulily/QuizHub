import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/bloc/paged_cubit.dart';
import 'package:quizhub/core/network/api_exception.dart';
import 'package:quizhub/data/models/cursor_page.dart';

void main() {
  test('tải trang đầu, dùng cursor tiếp theo và dừng ở trang cuối', () async {
    final cursors = <String?>[];
    final cubit = PagedCubit<int>((after) async {
      cursors.add(after);
      return after == null
          ? const CursorPage(items: [1, 2], after: 'next', hasNext: true)
          : const CursorPage(items: [3], hasNext: false);
    });
    addTearDown(cubit.close);

    await cubit.load();
    expect(cubit.state.items, [1, 2]);
    expect(cubit.state.hasNext, isTrue);

    await cubit.loadMore();
    expect(cursors, [null, 'next']);
    expect(cubit.state.items, [1, 2, 3]);
    expect(cubit.state.hasNext, isFalse);

    await cubit.loadMore();
    expect(cursors, [null, 'next']);
  });

  test('giữ dữ liệu và cursor khi tải lỗi để có thể thử lại', () async {
    var attempts = 0;
    final cubit = PagedCubit<int>((after) async {
      if (after == null) {
        return const CursorPage(items: [1], after: 'next', hasNext: true);
      }
      if (++attempts == 1) {
        throw const ApiException(type: ApiErrorType.server, message: 'failed');
      }
      return const CursorPage(items: [2], hasNext: false);
    });
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.loadMore();
    expect(cubit.state.items, [1]);
    expect(cubit.state.after, 'next');
    expect(cubit.state.loadingMore, isFalse);
    expect(cubit.state.error, isNotNull);

    await cubit.loadMore();
    expect(cubit.state.items, [1, 2]);
    expect(cubit.state.error, isNull);
  });

  test('không gửi nhiều yêu cầu đồng thời cho cùng trang kế tiếp', () async {
    final pending = Completer<CursorPage<int>>();
    var nextPageCalls = 0;
    final cubit = PagedCubit<int>((after) async {
      if (after == null) {
        return const CursorPage(items: [1], after: 'next', hasNext: true);
      }
      nextPageCalls++;
      return pending.future;
    });
    addTearDown(cubit.close);

    await cubit.load();
    final first = cubit.loadMore();
    final second = cubit.loadMore();
    expect(nextPageCalls, 1);

    pending.complete(const CursorPage(items: [2], hasNext: false));
    await Future.wait([first, second]);
    expect(cubit.state.items, [1, 2]);
  });

  test('coi mã hết dữ liệu là trang cuối và giữ các mục đã tải', () async {
    var nextPageCalls = 0;
    final cubit = PagedCubit<int>((after) async {
      if (after == null) {
        return const CursorPage(items: [1], after: 'next', hasNext: true);
      }
      nextPageCalls++;
      throw const ApiException(
        type: ApiErrorType.business,
        message: 'no more data',
        code: '9994',
      );
    });
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.loadMore();
    expect(cubit.state.items, [1]);
    expect(cubit.state.hasNext, isFalse);
    expect(cubit.state.error, isNull);

    await cubit.loadMore();
    expect(nextPageCalls, 1);
  });
}
