import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/session_events.dart';
import 'package:quizhub/core/services/chat_realtime.dart';
import 'package:quizhub/core/storage/token_storage.dart';
import 'package:quizhub/data/repositories/chat_repository.dart';
import 'package:quizhub/dev/preview_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/chat_demo_server.dart';

class _MemoryPreferences implements SharedPreferences {
  final Map<String, Object> _values = {};

  @override
  Object? get(String key) => _values[key];

  @override
  String? getString(String key) => _values[key] as String?;

  @override
  List<String>? getStringList(String key) => _values[key] as List<String>?;

  @override
  Set<String> getKeys() => _values.keys.toSet();

  @override
  Future<bool> setString(String key, String value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _values.remove(key);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DemoTokens extends TokenStorage {
  final int id;
  _DemoTokens(this.id);

  @override
  String get accessToken => 'chat-demo-$id';
  @override
  String get refreshToken => 'chat-demo-refresh-$id';
  @override
  bool get hasTokens => true;
  @override
  Future<void> load() async {}
}

class _DemoClient {
  final SessionEvents sessions = SessionEvents();
  late final ApiClient api;
  late final ChatRepository repo;
  late final StompChatRealtime realtime;

  _DemoClient(int id, String baseUrl) {
    final tokens = _DemoTokens(id);
    api = ApiClient(tokens: tokens, events: sessions, baseUrl: baseUrl);
    repo = ChatRepository(api);
    realtime = StompChatRealtime(
      api,
      tokens,
      sessions,
      url: '${baseUrl.replaceFirst('http', 'ws')}/ws/websocket',
      retryBase: const Duration(milliseconds: 30),
    );
  }

  Future<void> connect() async {
    await realtime.acquire();
    await _until(() => realtime.connection == ChatConnection.connected);
  }

  Future<void> close() async {
    await realtime.dispose();
    sessions.dispose();
  }
}

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(condition(), isTrue, reason: 'Mock chat event/connection timed out');
}

Future<void> _untilAsync(Future<bool> Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(await condition(), isTrue, reason: 'Mock chat message timed out');
}

void main() {
  test(
    'preview list summary falls back after revoked message is deleted ME and restart',
    () async {
      final preferences = _MemoryPreferences();
      var backend = PreviewBackend(preferences: preferences);
      var sessions = SessionEvents();
      var repo = ChatRepository(
        ApiClient(
          tokens: PreviewTokens(),
          events: sessions,
          baseUrl: 'https://preview.test/api/v1',
          adapter: backend,
        ),
      );
      addTearDown(sessions.dispose);

      final conversation = await repo.direct(2, myId: 1);
      final chat = backend.chat;
      final older = await chat.appendSaved(
        conversation.conversationId,
        1,
        'older-visible-sentinel',
        'TEXT',
        const [],
      );
      final target = await chat.appendSaved(
        conversation.conversationId,
        1,
        'revoke-then-delete-sentinel',
        'TEXT',
        const [],
      );
      await repo.deleteMessage(target.messageId, forEveryone: true);
      final revokedSummary = (await repo.conversations()).items.firstWhere(
        (row) => row.conversationId == conversation.conversationId,
      );
      expect(revokedSummary.lastMessage?.messageId, target.messageId);
      expect(revokedSummary.lastMessage?.preview, 'Tin nhắn đã thu hồi');

      await repo.deleteMessage(target.messageId);
      final current = (await repo.conversations()).items.firstWhere(
        (row) => row.conversationId == conversation.conversationId,
      );
      expect(current.lastMessage?.messageId, older.messageId);
      expect(current.lastMessage?.content, 'older-visible-sentinel');

      await chat.flush();
      backend = PreviewBackend(preferences: preferences);
      sessions = SessionEvents();
      repo = ChatRepository(
        ApiClient(
          tokens: PreviewTokens(),
          events: sessions,
          baseUrl: 'https://preview.test/api/v1',
          adapter: backend,
        ),
      );
      addTearDown(sessions.dispose);
      final restored = (await repo.conversations()).items.firstWhere(
        (row) => row.conversationId == conversation.conversationId,
      );
      expect(restored.lastMessage?.messageId, older.messageId);
      expect(restored.lastMessage?.content, 'older-visible-sentinel');
      expect(
        (await repo.messages(
          conversation.conversationId,
        )).items.any((message) => message.messageId == target.messageId),
        isFalse,
      );
    },
  );

  test(
    'shared REST summaries stay user-specific after revoked message is deleted ME and restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'quizhub-chat-preview-',
      );
      var server = await ChatDemoServer.start(dataDirectory: directory);
      final clients = <_DemoClient>[];
      _DemoClient client(int id) {
        final result = _DemoClient(id, server.baseUrl);
        clients.add(result);
        return result;
      }

      Future<void> restart() async {
        for (final value in clients) {
          await value.close();
        }
        clients.clear();
        final port = server.port;
        await server.close();
        server = await ChatDemoServer.start(
          dataDirectory: directory,
          port: port,
        );
      }

      addTearDown(() async {
        for (final value in clients) {
          await value.close();
        }
        await server.close();
        await directory.delete(recursive: true);
      });

      final an = client(1);
      final lan = client(2);
      await Future.wait([an.connect(), lan.connect()]);
      final conversation = await an.repo.direct(2, myId: 1);
      await lan.repo.direct(1, myId: 2);

      an.realtime.send(
        conversationId: conversation.conversationId,
        content: 'older-visible-sentinel',
      );
      await _untilAsync(() async {
        final rows = (await an.repo.messages(
          conversation.conversationId,
        )).items;
        return rows.any((m) => m.content == 'older-visible-sentinel');
      });
      final older = (await an.repo.messages(
        conversation.conversationId,
      )).items.singleWhere((m) => m.content == 'older-visible-sentinel');

      an.realtime.send(
        conversationId: conversation.conversationId,
        content: 'revoke-then-delete-sentinel',
      );
      await _untilAsync(() async {
        final rows = (await lan.repo.messages(
          conversation.conversationId,
        )).items;
        return rows.any((m) => m.content == 'revoke-then-delete-sentinel');
      });
      final target = (await an.repo.messages(
        conversation.conversationId,
      )).items.singleWhere((m) => m.content == 'revoke-then-delete-sentinel');

      await an.repo.deleteMessage(target.messageId, forEveryone: true);
      for (final account in [an, lan]) {
        await _untilAsync(() async {
          final rows = (await account.repo.messages(
            conversation.conversationId,
          )).items;
          return rows.any((m) => m.messageId == target.messageId && m.revoked);
        });
        final summary = (await account.repo.conversations()).items.single;
        expect(summary.lastMessage?.messageId, target.messageId);
        expect(summary.lastMessage?.preview, 'Tin nhắn đã thu hồi');
      }

      await an.repo.deleteMessage(target.messageId);
      final anHistory = (await an.repo.messages(
        conversation.conversationId,
      )).items;
      final lanHistory = (await lan.repo.messages(
        conversation.conversationId,
      )).items;
      expect(anHistory.any((m) => m.messageId == target.messageId), isFalse);
      expect(
        lanHistory.singleWhere((m) => m.messageId == target.messageId).revoked,
        isTrue,
      );
      final anSummary = (await an.repo.conversations()).items.single;
      final lanSummary = (await lan.repo.conversations()).items.single;
      expect(anSummary.lastMessage?.messageId, older.messageId);
      expect(anSummary.lastMessage?.content, 'older-visible-sentinel');
      expect(lanSummary.lastMessage?.messageId, target.messageId);
      expect(lanSummary.lastMessage?.preview, 'Tin nhắn đã thu hồi');

      await restart();
      final restoredAn = client(1);
      final restoredLan = client(2);
      final afterAn = (await restoredAn.repo.conversations()).items.single;
      final afterLan = (await restoredLan.repo.conversations()).items.single;
      expect(afterAn.lastMessage?.messageId, older.messageId);
      expect(afterAn.lastMessage?.content, 'older-visible-sentinel');
      expect(afterLan.lastMessage?.messageId, target.messageId);
      expect(afterLan.lastMessage?.preview, 'Tin nhắn đã thu hồi');
    },
  );
}
