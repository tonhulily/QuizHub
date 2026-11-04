import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/json_utils.dart';
import '../models/author_model.dart';
import '../models/chat_models.dart';
import '../models/cursor_page.dart';

class ChatRepository {
  final ApiClient _api;
  ChatRepository(this._api);

  Future<bool> blockedWith(int userId) => _api.get(
    ApiEndpoints.userRelationshipStats(userId),
    parser: (d) =>
        J.asBool(J.asMap(J.asMap(d)?['relationship_with_me'])?['blocked']),
  );

  Future<CursorPage<ChatConversation>> conversations({String? after}) =>
      _api.get(
        ApiEndpoints.conversations,
        query: {'after': after, 'limit': 20},
        parser: (d) => CursorPage.fromJson(d, ChatConversation.fromJson),
      );

  Future<ChatConversation> direct(int userId, {required int myId}) => _api.post(
    ApiEndpoints.conversationsDirect,
    body: {'target_user_id': userId},
    parser: (d) =>
        ChatConversation.fromJson(J.asMap(d) ?? const {}, myId: myId),
  );

  Future<List<AuthorModel>> members(int conversationId) => _api.get(
    ApiEndpoints.conversationMembers(conversationId),
    parser: (d) => J.list(d, AuthorModel.fromJson),
  );

  Future<CursorPage<ChatMessage>> messages(
    int conversationId, {
    String? after,
  }) => _api.get(
    ApiEndpoints.conversationMessages(conversationId),
    query: {'after': after, 'limit': 20},
    parser: (d) => CursorPage.fromJson(
      d,
      (j) => ChatMessage.fromJson(j, conversationId: conversationId),
      itemsKey: 'messages',
    ),
  );

  Future<void> deleteMessage(int id, {bool forEveryone = false}) =>
      _api.deleteVoid(
        ApiEndpoints.message(id),
        body: {'scope': forEveryone ? 'EVERYONE' : 'ME'},
      );
}
