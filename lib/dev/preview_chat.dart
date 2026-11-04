/// Dữ liệu chat trong RAM cho bản xem trước; không gọi backend thật.
class PreviewChat {
  static const unhandled = Object();
  final Map<String, dynamic> Function(int) person;
  final Map<String, dynamic> me;
  final bool Function(int) isBlocked;
  final Map<int, int> peers = {1: 2, 2: 4};
  final Map<int, List<Map<String, dynamic>>> messages = {};
  int nextMessageId = 100;

  PreviewChat({
    required this.person,
    required this.me,
    required this.isBlocked,
  }) {
    for (final id in peers.keys) {
      messages[id] = [
        for (var i = 0; i < 25; i++)
          {
            'message_id': id * 100 + i,
            'conversation_id': id,
            'sender_id': i.isEven ? peers[id] : 1,
            'sender_name': i.isEven
                ? person(peers[id]!)['full_name']
                : me['full_name'],
            'content': i == 24
                ? 'Hẹn bạn buổi học tiếp theo nhé!'
                : 'Tin nhắn trao đổi bài học ${i + 1}',
            'message_type': 'TEXT',
            'media_urls': <String>[],
            'created_at': DateTime.now()
                .subtract(Duration(minutes: 26 - i))
                .toUtc()
                .toIso8601String(),
            'revoked': false,
          },
      ];
    }
    nextMessageId = 300;
  }

  Map<String, dynamic> _member(int id) => id == 1 ? me : person(id);
  Map<String, dynamic> _page(
    List<Map<String, dynamic>> all,
    Map<String, dynamic> query, {
    String key = 'items',
  }) {
    final after = int.tryParse('${query['after']}') ?? 0;
    final limit = int.tryParse('${query['limit']}') ?? 20;
    final items = all.skip(after).take(limit).toList();
    final end = after + items.length;
    return {
      key: items,
      'pagination': {
        'after': end < all.length ? end : null,
        'has_next': end < all.length,
      },
    };
  }

  Object? route(
    String method,
    String path,
    Map<String, dynamic> query,
    Map<String, dynamic> body,
  ) {
    if (path == '/conversations' && method == 'GET') {
      final rows = [
        for (final entry in peers.entries)
          {
            'conversation_id': entry.key,
            'type': 'DIRECT',
            'display_name': person(entry.value)['full_name'],
            'display_avatar_url': person(entry.value)['avatar_url'],
            'last_message': messages[entry.key]?.lastOrNull,
            'unread_count': 0,
            'updated_at': messages[entry.key]?.lastOrNull?['created_at'],
          },
      ];
      rows.sort((a, b) => '${b['updated_at']}'.compareTo('${a['updated_at']}'));
      return _page(rows, query);
    }
    if (path == '/conversations/direct' && method == 'POST') {
      final peerId = int.parse('${body['target_user_id']}');
      var id = peers.entries.where((e) => e.value == peerId).firstOrNull?.key;
      if (id == null) {
        id = peers.length + 1;
        peers[id] = peerId;
        messages[id] = [];
      }
      return {
        'conversation_id': id,
        'type': 'DIRECT',
        'members': [_member(1), _member(peerId)],
      };
    }
    final match = RegExp(
      r'^/conversations/(\d+)/(messages|members)$',
    ).firstMatch(path);
    if (match != null && method == 'GET') {
      final id = int.parse(match[1]!);
      if (match[2] == 'members') return [_member(1), _member(peers[id]!)];
      return {
        'conversation_id': id,
        'conversation_type': 'DIRECT',
        ..._page(
          (messages[id] ?? []).reversed.toList(),
          query,
          key: 'messages',
        ),
      };
    }
    final deletion = RegExp(r'^/messages/(\d+)$').firstMatch(path);
    if (deletion != null && method == 'DELETE') {
      final id = int.parse(deletion[1]!);
      for (final list in messages.values) {
        if (body['scope'] == 'EVERYONE') {
          for (final m in list.where((m) => m['message_id'] == id)) {
            m['revoked'] = true;
            m['content'] = '';
          }
        } else {
          list.removeWhere((m) => m['message_id'] == id);
        }
      }
      return {'message_id': id, 'scope': body['scope']};
    }
    return unhandled;
  }
}
