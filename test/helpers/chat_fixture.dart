import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/session_events.dart';
import 'package:quizhub/data/repositories/chat_repository.dart';
import 'package:quizhub/dev/preview_backend.dart';
import 'package:quizhub/dev/preview_chat.dart';

class ChatFixture implements HttpClientAdapter {
  final blocked = <int>{};
  final sessions = SessionEvents();
  late final data = PreviewChat(
    person: (id) => {'user_id': id, 'full_name': 'Bạn $id'},
    me: {'user_id': 1, 'full_name': 'Tôi'},
    isBlocked: blocked.contains,
  );
  late final repo = ChatRepository(
    ApiClient(tokens: PreviewTokens(), events: sessions, adapter: this),
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? request,
    Future<void>? cancel,
  ) async => ResponseBody.fromString(
    jsonEncode({
      'code': '0000',
      'data': data.route(
        options.method,
        options.path,
        options.queryParameters,
        options.data is Map ? Map<String, dynamic>.from(options.data) : {},
      ),
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
  Future<void> dispose() async {
    await data.realtime.dispose();
    sessions.dispose();
  }
}
