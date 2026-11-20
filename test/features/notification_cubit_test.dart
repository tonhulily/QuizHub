import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/bloc/paged_cubit.dart';

import 'package:quizhub/core/network/api_exception.dart';
import 'package:quizhub/data/models/cursor_page.dart';
import 'package:quizhub/data/models/notification_models.dart';
import 'package:quizhub/data/repositories/notification_repository.dart';
import 'package:quizhub/features/notifications/cubit/notification_cubit.dart';

class FakeNotificationRepository implements NotificationRepository {
  final List<String?> requestedCursors = [];

  List<NotificationPageResponse> pages = [];

  int markAsReadCalls = 0;
  int markAllAsReadCalls = 0;

  ApiException? getNotificationsError;
  ApiException? markAsReadError;
  ApiException? markAllAsReadError;

  Completer<MarkNotificationReadResponse>? markReadCompleter;
  Completer<void>? markAllCompleter;
  Completer<NotificationPageResponse>? pageCompleter;

  @override
  Future<NotificationPageResponse> getNotifications({
    String? after,
    int limit = 20,
  }) async {
    requestedCursors.add(after);

    if (getNotificationsError != null) {
      throw getNotificationsError!;
    }

    if (pageCompleter != null) {
      return pageCompleter!.future;
    }

    if (pages.isEmpty) {
      return const NotificationPageResponse(
        page: CursorPage<NotificationModel>(),
      );
    }

    return pages.removeAt(0);
  }

  @override
  Future<MarkNotificationReadResponse> markAsRead(
    int notificationId,
  ) async {
    markAsReadCalls++;

    if (markReadCompleter != null) {
      return markReadCompleter!.future;
    }

    if (markAsReadError != null) {
      throw markAsReadError!;
    }

    return MarkNotificationReadResponse(
      notificationId: notificationId,
      readAt: DateTime.utc(2026, 11, 15),
      unreadCount: 2,
    );
  }

  @override
  Future<void> markAllAsRead() async {
    markAllAsReadCalls++;

    if (markAllCompleter != null) {
      return markAllCompleter!.future;
    }

    if (markAllAsReadError != null) {
      throw markAllAsReadError!;
    }
  }
}

NotificationModel createNotification({
  int id = 1,
  DateTime? readAt,
}) {
  return NotificationModel(
    notificationId: id,
    type: 'FRIEND_REQUEST',
    title: 'Thông báo $id',
    body: 'Nội dung $id',
    readAt: readAt,
  );
}

NotificationPageResponse createPage(
  List<NotificationModel> items, {
  String? after,
  bool hasNext = false,
  int unreadCount = 0,
}) {
  return NotificationPageResponse(
    page: CursorPage<NotificationModel>(
      items: items,
      after: after,
      hasNext: hasNext,
    ),
    unreadCount: unreadCount,
  );
}

ApiException createApiError() {
  return const ApiException(
    type: ApiErrorType.server,
    message: 'Server error',
    statusCode: 500,
  );
}

void main() {
  late FakeNotificationRepository repository;
  late NotificationCubit cubit;

  setUp(() {
    repository = FakeNotificationRepository();
    cubit = NotificationCubit(repository);
  });

  tearDown(() async {
    await cubit.close();
  });

  group('load', () {
    test('tải trang đầu và cập nhật unread count', () async {
      repository.pages = [
        createPage(
          [createNotification(id: 1), createNotification(id: 2)],
          after: 'cursor-1',
          hasNext: true,
          unreadCount: 5,
        ),
      ];

      await cubit.load();

      expect(cubit.notificationsCubit.state.items, hasLength(2));
      expect(cubit.notificationsCubit.state.after, 'cursor-1');
      expect(cubit.notificationsCubit.state.hasNext, true);
      expect(cubit.state.unreadCount, 5);
      expect(cubit.notificationsCubit.state.status, PagedStatus.loaded);
    });

    test('loadMore truyền cursor và nối thêm dữ liệu', () async {
      repository.pages = [
        createPage(
          [createNotification(id: 1)],
          after: 'cursor-1',
          hasNext: true,
          unreadCount: 3,
        ),
        createPage(
          [createNotification(id: 2)],
          after: null,
          hasNext: false,
          unreadCount: 2,
        ),
      ];

      await cubit.load();
      await cubit.notificationsCubit.loadMore();

      expect(repository.requestedCursors, [null, 'cursor-1']);
      expect(cubit.notificationsCubit.state.items, hasLength(2));
      expect(cubit.notificationsCubit.state.hasNext, false);
      expect(cubit.state.unreadCount, 2);
    });

    test('refresh thay thế danh sách cũ bằng dữ liệu mới', () async {
      repository.pages = [
        createPage([createNotification(id: 1)], unreadCount: 1),
        createPage([createNotification(id: 2)], unreadCount: 4),
      ];

      await cubit.load();
      await cubit.refresh();

      expect(cubit.notificationsCubit.state.items.single.notificationId, 2);
      expect(cubit.state.unreadCount, 4);
    });

    test('lỗi khi load được giữ trong PagedCubit', () async {
      repository.getNotificationsError = createApiError();

      await cubit.load();

      expect(
        cubit.notificationsCubit.state.status,
        PagedStatus.failure,
      );
      expect(cubit.notificationsCubit.state.error, isNotNull);
    });
  });

  group('markAsRead', () {
    test('đánh dấu đã đọc và cập nhật unread count', () async {
      repository.pages = [
        createPage(
          [createNotification(id: 1)],
          unreadCount: 3,
        ),
      ];

      await cubit.load();

      final result = await cubit.markAsRead(
        cubit.notificationsCubit.state.items.first,
      );

      final updated = cubit.notificationsCubit.state.items.first;

      expect(result, isNull);
      expect(updated.isRead, true);
      expect(cubit.state.unreadCount, 2);
      expect(cubit.state.busyNotificationIds, isEmpty);
    });

    test('không gọi API nếu thông báo đã đọc', () async {
      repository.pages = [
        createPage([
          createNotification(
            id: 1,
            readAt: DateTime.utc(2026, 11, 15),
          ),
        ]),
      ];

      await cubit.load();

      await cubit.markAsRead(
        cubit.notificationsCubit.state.items.first,
      );

      expect(repository.markAsReadCalls, 0);
    });

    test('không gọi API trùng khi request đầu đang xử lý', () async {
      repository.pages = [
        createPage([createNotification(id: 1)]),
      ];

      await cubit.load();

      repository.markReadCompleter =
          Completer<MarkNotificationReadResponse>();

      final notification = cubit.notificationsCubit.state.items.first;

      final firstCall = cubit.markAsRead(notification);

      expect(cubit.state.busyNotificationIds, contains(1));

      final secondCall = await cubit.markAsRead(notification);

      expect(secondCall, isNull);
      expect(repository.markAsReadCalls, 1);

      repository.markReadCompleter!.complete(
        MarkNotificationReadResponse(
          notificationId: 1,
          unreadCount: 0,
          readAt: DateTime.utc(2026, 11, 15),
        ),
      );

      await firstCall;

      expect(cubit.state.busyNotificationIds, isEmpty);
      expect(cubit.notificationsCubit.state.items.first.isRead, true);
    });

    test('API lỗi thì giữ thông báo chưa đọc và giải phóng busy', () async {
      repository.pages = [
        createPage([createNotification(id: 1)]),
      ];

      await cubit.load();

      repository.markAsReadError = createApiError();

      final result = await cubit.markAsRead(
        cubit.notificationsCubit.state.items.first,
      );

      expect(result, isNotNull);
      expect(cubit.state.actionError, isNotNull);
      expect(cubit.state.busyNotificationIds, isEmpty);
      expect(cubit.notificationsCubit.state.items.first.isRead, false);
    });
  });

  group('markAllAsRead', () {
    test('đánh dấu toàn bộ thông báo hiện tại đã đọc', () async {
      repository.pages = [
        createPage([
          createNotification(id: 1),
          createNotification(id: 2),
          createNotification(
            id: 3,
            readAt: DateTime.utc(2026, 11, 15),
          ),
        ], unreadCount: 2),
      ];

      await cubit.load();

      final result = await cubit.markAllAsRead();

      expect(result, isNull);
      expect(repository.markAllAsReadCalls, 1);
      expect(cubit.state.unreadCount, 0);
      expect(cubit.state.markingAllAsRead, false);
      expect(
        cubit.notificationsCubit.state.items.every((item) => item.isRead),
        true,
      );
    });

    test('API lỗi thì giữ nguyên danh sách và trả về lỗi', () async {
      repository.pages = [
        createPage([
          createNotification(id: 1),
        ], unreadCount: 1),
      ];

      await cubit.load();

      repository.markAllAsReadError = createApiError();

      final result = await cubit.markAllAsRead();

      expect(result, isNotNull);
      expect(cubit.state.actionError, isNotNull);
      expect(cubit.state.markingAllAsRead, false);
      expect(cubit.state.unreadCount, 1);
      expect(cubit.notificationsCubit.state.items.first.isRead, false);
    });

    test('không thực hiện khi đang có request markAsRead', () async {
      repository.pages = [
        createPage([createNotification(id: 1)]),
      ];

      await cubit.load();

      repository.markReadCompleter =
          Completer<MarkNotificationReadResponse>();

      final firstCall = cubit.markAsRead(
        cubit.notificationsCubit.state.items.first,
      );

      final result = await cubit.markAllAsRead();

      expect(result, isNull);
      expect(repository.markAllAsReadCalls, 0);

      repository.markReadCompleter!.complete(
        MarkNotificationReadResponse(
          notificationId: 1,
          unreadCount: 0,
        ),
      );

      await firstCall;
    });
  });

  group('onPushReceived', () {
    test('tải lại danh sách khi nhận push', () async {
      repository.pages = [
        createPage([createNotification(id: 1)], unreadCount: 1),
        createPage([
          createNotification(id: 1),
          createNotification(id: 2),
        ], unreadCount: 2),
      ];

      await cubit.load();
      await cubit.onPushReceived();

      expect(cubit.notificationsCubit.state.items, hasLength(2));
      expect(cubit.state.unreadCount, 2);
    });

    test('bỏ qua push trùng khi lần đồng bộ trước chưa hoàn thành', () async {
      repository.pages = [
        createPage([createNotification(id: 1)]),
      ];

      await cubit.load();

      repository.pageCompleter =
          Completer<NotificationPageResponse>();

      final firstCall = cubit.onPushReceived();

      // Đợi request đầu tiên bắt đầu.
      await Future<void>.delayed(Duration.zero);

      final secondCall = cubit.onPushReceived();

      await secondCall;

      expect(repository.requestedCursors.length, 2);

      repository.pageCompleter!.complete(
        createPage([
          createNotification(id: 1),
          createNotification(id: 2),
        ], unreadCount: 2),
      );

      await firstCall;

      expect(cubit.notificationsCubit.state.items, hasLength(2));
    });
  });
}
