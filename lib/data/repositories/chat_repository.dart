import '../../core/network/api_client.dart';
import '../../core/services/blocked_users.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/json_utils.dart';
import '../models/author_model.dart';
import '../models/chat_models.dart';
import '../models/cursor_page.dart';

class ChatRepository {
  final ApiClient _api;
  final BlockedUsers? _blocks;
  final Map<int, List<AuthorModel>> _members = {};
  int? _cachedOwner;
  ChatRepository(this._api, {BlockedUsers? blocks}) : _blocks = blocks;

  Future<bool> blockedWith(int userId) async {
    if (_blocks?.contains(userId) ?? false) return true;
    return _api.get(
      ApiEndpoints.userRelationshipStats(userId),
      parser: (d) =>
          J.asBool(J.asMap(J.asMap(d)?['relationship_with_me'])?['blocked']),
    );
  }

  void _checkOwner() {
    final owner = _blocks?.ownerId;
    if (_cachedOwner != owner) {
      _cachedOwner = owner;
      _members.clear();
    }
  }

  Future<List<AuthorModel>> _loadMembers(int conversationId) async {
    _checkOwner();
    final owner = _cachedOwner;
    final members = await _api.get(
      ApiEndpoints.conversationMembers(conversationId),
      parser: (d) => J.list(d, AuthorModel.fromJson),
    );
    if (owner == _blocks?.ownerId) _members[conversationId] = members;
    return members;
  }

  void _requireMembersVisible(List<AuthorModel> members) {
    if (members.any((m) => _blocks?.contains(m.userId) ?? false)) {
      throw BlockedUsers.unavailable;
    }
  }

  Future<void> _requireConversationVisible(int id) async {
    _checkOwner();
    if (_blocks?.ids.isEmpty ?? true) return;
    _requireMembersVisible(_members[id] ?? await _loadMembers(id));
  }

  Future<CursorPage<ChatConversation>> conversations({String? after}) async {
    final page = await _api.get(
      ApiEndpoints.conversations,
      query: {'after': after, 'limit': 20},
      parser: (d) => CursorPage.fromJson(d, ChatConversation.fromJson),
    );
    final visible = <ChatConversation>[];
    _checkOwner();
    for (final conversation in page.items) {
      var row = conversation;
      if (row.type == 'DIRECT' && !(_blocks?.ids.isEmpty ?? true)) {
        if (row.members.isEmpty) {
          row = row.withMembers(await _loadMembers(row.conversationId));
        }
        if (row.members.any((u) => _blocks?.contains(u.userId) ?? false)) {
          continue;
        }
      }
      if (row.members.isNotEmpty) _members[row.conversationId] = row.members;
      visible.add(row);
    }
    return CursorPage(items: visible, after: page.after, hasNext: page.hasNext);
  }

  Future<ChatConversation> direct(int userId, {required int myId}) async {
    _blocks?.requireVisible(userId);
    final conversation = await _api.post(
      ApiEndpoints.conversationsDirect,
      body: {'target_user_id': userId},
      parser: (d) =>
          ChatConversation.fromJson(J.asMap(d) ?? const {}, myId: myId),
    );
    _blocks?.requireVisible(userId);
    _checkOwner();
    _members[conversation.conversationId] = conversation.members;
    return conversation;
  }

  Future<List<AuthorModel>> members(int conversationId) async {
    final members = await _loadMembers(conversationId);
    _requireMembersVisible(members);
    return members;
  }

  Future<CursorPage<ChatMessage>> messages(
    int conversationId, {
    String? after,
  }) async {
    await _requireConversationVisible(conversationId);
    final page = await _api.get(
      ApiEndpoints.conversationMessages(conversationId),
      query: {'after': after, 'limit': 20},
      parser: (d) => CursorPage.fromJson(
        d,
        (j) => ChatMessage.fromJson(j, conversationId: conversationId),
        itemsKey: 'messages',
      ),
    );
    await _requireConversationVisible(conversationId);
    return page.filtered((m) => !(_blocks?.contains(m.senderId) ?? false));
  }

  Future<void> deleteMessage(int id, {bool forEveryone = false}) =>
      _api.deleteVoid(
        ApiEndpoints.message(id),
        body: {'scope': forEveryone ? 'EVERYONE' : 'ME'},
      );
}
