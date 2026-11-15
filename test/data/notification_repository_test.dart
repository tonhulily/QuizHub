import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/api_endpoints.dart';
import 'package:quizhub/core/network/response_codes.dart';
import 'package:quizhub/core/network/session_events.dart';
import 'package:quizhub/core/storage/token_storage.dart';
import 'package:quizhub/data/repositories/notification_repository.dart';

class FakeHttpClientAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  dynamic responseData;

  FakeHttpClientAdapter({this.responseData});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    return ResponseBody.fromString(
      jsonEncode({
        'code': ResponseCodes.success,
        'message': 'Success',
        'data': responseData ?? {},
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

void main() {
  late FakeHttpClientAdapter adapter;
  late NotificationRepository repository;

  setUp(() {
    adapter = FakeHttpClientAdapter();

    final api = ApiClient(
      tokens: TokenStorage(),
      events: SessionEvents(),
      baseUrl: 'https://test.local',
      adapter: adapter,
    );

    repository = NotificationRepository(api);
  });

  group('getNotifications', () {
    test('gửi GET với limit và after mặc định', () async {
      adapter.responseData = {
        'items': [],
        'pagination': {
          'after': null,
          'has_next': false,
        },
        'unread_count': 5,
      };

      final result = await repository.getNotifications();

      expect(adapter.requests, hasLength(1));

      final request = adapter.requests.first;

      expect(request.method, 'GET');
      expect(request.path, contains(ApiEndpoints.notifications));
      expect(request.queryParameters['limit'], isPositive);
      expect(request.queryParameters['after'], isNull);

      expect(result.unreadCount, 5);
      expect(result.page.items, isEmpty);
      expect(result.page.hasNext, false);
    });

    test('truyền cursor và giới hạn limit tối đa 50', () async {
      adapter.responseData = {
        'items': [],
        'pagination': {
          'after': 'cursor-2',
          'has_next': true,
        },
        'unread_count': 10,
      };

      final result = await repository.getNotifications(
        after: 'cursor-1',
        limit: 100,
      );

      final request = adapter.requests.first;

      expect(request.queryParameters['after'], 'cursor-1');
      expect(request.queryParameters['limit'], 50);
      expect(result.page.after, 'cursor-2');
      expect(result.page.hasNext, true);
    });

    test('giới hạn limit tối thiểu bằng 1', () async {
      adapter.responseData = {
        'items': [],
        'pagination': {},
        'unread_count': 0,
      };

      await repository.getNotifications(limit: 0);

      expect(
        adapter.requests.first.queryParameters['limit'],
        1,
      );
    });

    test('parse danh sách thông báo và unread count', () async {
      adapter.responseData = {
        'items': [
          {
            'notification_id': 101,
            'type': 'FRIEND_REQUEST',
            'title': 'Lời mời kết bạn',
            'body': 'Nguyễn Văn A đã gửi lời mời',
            'read_at': null,
            'created_at': '2026-11-15T08:00:00Z',
            'actor': {
              'user_id': 10,
              'full_name': 'Nguyễn Văn A',
            },
          },
        ],
        'pagination': {
          'after': 'next-cursor',
          'has_next': true,
        },
        'unread_count': 3,
      };

      final result = await repository.getNotifications();

      expect(result.unreadCount, 3);
      expect(result.page.items, hasLength(1));

      final notification = result.page.items.first;

      expect(notification.notificationId, 101);
      expect(notification.type, 'FRIEND_REQUEST');
      expect(notification.isRead, false);
      expect(notification.actor?.userId, 10);
      expect(notification.actor?.fullName, 'Nguyễn Văn A');
    });
  });

  group('markAsRead', () {
    test('gửi POST tới endpoint của notification ID', () async {
      adapter.responseData = {
        'notification_id': 101,
        'read_at': '2026-11-15T08:00:00Z',
        'unread_count': 2,
        'read': true,
      };

      final result = await repository.markAsRead(101);

      final request = adapter.requests.first;

      expect(request.method, 'POST');
      expect(
        request.path,
        contains(ApiEndpoints.notificationRead(101)),
      );

      expect(result.notificationId, 101);
      expect(result.read, true);
      expect(result.unreadCount, 2);
      expect(result.readAt, isNotNull);
    });

    test('từ chối ID không hợp lệ mà không gửi request', () {
      expect(
        () => repository.markAsRead(0),
        throwsArgumentError,
      );

      expect(
        () => repository.markAsRead(-1),
        throwsArgumentError,
      );

      expect(adapter.requests, isEmpty);
    });
  });

  group('markAllAsRead', () {
    test('gửi POST tới endpoint đọc tất cả', () async {
      adapter.responseData = {};

      await repository.markAllAsRead();

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.first.method, 'POST');
      expect(
        adapter.requests.first.path,
        contains(ApiEndpoints.notificationsReadAll),
      );
    });
  });
}
