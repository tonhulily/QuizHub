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
      await f; // trước đây ném "Cannot emit new states after calling close"
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
      first.complete(_page([1])); // lần 1 về sau lần 2
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
  });
}