import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/bloc/paged_cubit.dart';
import 'package:quizhub/core/network/api_exception.dart';
import 'package:quizhub/data/models/cursor_page.dart';

CursorPage<int> _page(List<int> items) =>
    CursorPage<int>(items: items, after: null, hasNext: false);

void main() {
  group('PagedCubit', () {
    test('đóng cubit trước khi tải xong thì không lỗi, không emit', () async {
      final c = Completer<CursorPage<int>>();
      final cubit = PagedCubit<int>((_) => c.future);
      final f = cubit.load();
      await cubit.close();
      c.complete(_page([1]));
      await f;
    });

    test('đóng cubit khi tải lỗi cũng không lỗi', () async {
      final c = Completer<CursorPage<int>>();
      final cubit = PagedCubit<int>((_) => c.future);
      final f = cubit.load();
      await cubit.close();
      c.completeError(
        const ApiException(
          type: ApiErrorType.noConnection,
          message: 'Mất mạng',
        ),
      );
      await f;
    });

    test('kết quả của lần tải cũ về chậm không đè lần tải mới', () async {
      final first = Completer<CursorPage<int>>();
      final second = Completer<CursorPage<int>>();
      final pending = [first, second];
      final cubit = PagedCubit<int>((_) => pending.removeAt(0).future);

      final a = cubit.load();
      final b = cubit.load();
      second.complete(_page([2]));
      await b;
      first.complete(_page([1]));
      await a;

      expect(cubit.state.items, [2]);
      await cubit.close();
    });

    test(
      'reset: bỏ danh sách cũ, tải lỗi thì hiện lỗi chứ không hiện cũ',
      () async {
        var fail = false;
        final cubit = PagedCubit<int>((_) async {
          if (fail) {
            throw const ApiException(
              type: ApiErrorType.noConnection,
              message: 'Mất mạng',
            );
          }
          return _page([1, 2]);
        });
        await cubit.load();
        expect(cubit.state.items, [1, 2]);

        fail = true;
        cubit.reset();
        expect(cubit.state.items, isEmpty);
        await cubit.load();
        expect(cubit.state.status, PagedStatus.failure);
        expect(cubit.state.items, isEmpty);
        await cubit.close();
      },
    );

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
  });
}
