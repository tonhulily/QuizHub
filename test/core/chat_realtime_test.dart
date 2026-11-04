import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/session_events.dart';
import 'package:quizhub/core/services/chat_realtime.dart';
import 'package:quizhub/core/storage/token_storage.dart';

class _Tokens extends TokenStorage {
  String value = 'first-token';
  @override
  String? get accessToken => value;
}

class _Api implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls++;
    return ResponseBody.fromString(
      '{"code":"0000","data":{}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue, reason: 'Hết thời gian chờ sự kiện STOMP');
}

void main() {
  test('phân biệt tin nhắn, biên nhận, typing và lỗi trong queue', () {
    expect(
      ChatEvent.fromJson({
        'conversation_id': 4,
        'message_id': 8,
        'sender_id': 2,
        'content': 'chào',
      }).message!.messageId,
      8,
    );
    final read = ChatEvent.fromJson({
      'type': 'READ_RECEIPT',
      'conversation_id': 4,
      'reader_id': 2,
      'message_id': 8,
    });
    expect(read.kind, ChatEventKind.read);
    expect(read.readMessageId, 8);
    expect(
      ChatEvent.fromJson({
        'conversation_id': 4,
        'user_id': 2,
        'is_typing': true,
      }).kind,
      ChatEventKind.typing,
    );
    expect(
      ChatEvent.fromJson({
        'code': 'USER_BLOCKED',
        'message': 'Bị chặn',
      }).error!.code,
      'USER_BLOCKED',
    );
  });

  test(
    'STOMP thật: xác thực CONNECT, gửi đúng destination và đăng ký lại sau ngắt mạng',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <WebSocket>[];
      final frames = <String>[];
      final subscriptions = <List<String>>[];
      final serverSubscription = server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        final destinations = <String>[];
        subscriptions.add(destinations);
        socket.listen((dynamic data) {
          final frame = data is String ? data : utf8.decode(data as List<int>);
          frames.add(frame);
          if (socket.readyState != WebSocket.open) return;
          if (frame.startsWith('DISCONNECT')) {
            final receipt = RegExp(
              r'receipt:([^\n]+)',
            ).firstMatch(frame)!.group(1)!;
            try {
              socket.add('RECEIPT\nreceipt-id:$receipt\n\n\u0000');
            } on StateError {
              /* Test chủ động đóng socket để giả lập mất mạng. */
            }
          }
          if (frame.startsWith('CONNECT')) {
            socket.add('CONNECTED\nversion:1.2\nheart-beat:0,0\n\n\u0000');
          }
          if (frame.startsWith('SUBSCRIBE')) {
            final destination = RegExp(
              r'destination:([^\n]+)',
            ).firstMatch(frame)!.group(1)!;
            destinations.add(destination);
            if (destination == '/user/queue/messages') {
              final id = RegExp(
                r'(?:^|\n)id:([^\n]+)',
              ).firstMatch(frame)!.group(1)!;
              final body = jsonEncode({
                'conversation_id': 1,
                'message_id': sockets.length,
                'sender_id': 2,
                'content': 'Tin realtime',
              });
              socket.add(
                'MESSAGE\nsubscription:$id\nmessage-id:test\ncontent-type:application/json\n\n$body\u0000',
              );
            }
          }
        });
      });
      final tokens = _Tokens();
      final adapter = _Api();
      final sessions = SessionEvents();
      final live = StompChatRealtime(
        ApiClient(tokens: tokens, events: sessions, adapter: adapter),
        tokens,
        sessions,
        url: 'ws://127.0.0.1:${server.port}',
        retryBase: const Duration(milliseconds: 20),
      );
      final events = <ChatEvent>[];
      final eventSubscription = live.events.listen(events.add);
      final unwatch = live.watchTyping(1);
      addTearDown(() async {
        unwatch();
        await live.dispose();
        await eventSubscription.cancel();
        sessions.dispose();
        for (final socket in sockets) {
          await socket.close();
        }
        await serverSubscription.cancel();
        await server.close(force: true);
      });
      await live.acquire();
      await _until(
        () => events.length == 1 && live.connection == ChatConnection.connected,
      );
      expect(
        frames.any((f) => f.contains('Authorization:Bearer first-token')),
        isTrue,
      );
      live.send(conversationId: 1, content: 'Gửi STOMP');
      await _until(
        () => frames.any(
          (f) => f.startsWith('SEND') && f.contains('/app/chat.send'),
        ),
      );
      tokens.value = 'refreshed-token';
      await sockets.first.close();
      await _until(
        () => events.length == 2 && live.connection == ChatConnection.connected,
      );
      expect(adapter.calls, 2);
      expect(
        frames.any((f) => f.contains('Authorization:Bearer refreshed-token')),
        isTrue,
      );
      for (final destinations in subscriptions) {
        expect(
          destinations.where((d) => d == '/user/queue/messages'),
          hasLength(1),
        );
        expect(
          destinations.where((d) => d == '/topic/conv.1.typing'),
          hasLength(1),
        );
      }
      live.disconnect();
      expect(
        () => live.send(conversationId: 1, content: 'offline'),
        throwsA(isA<Exception>()),
      );
    },
  );
}
