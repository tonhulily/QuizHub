import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';
import 'author_model.dart';

class ChatMessage extends Equatable {
  final int messageId;
  final int conversationId;
  final int senderId;
  final String senderName;
  final String? avatarUrl;
  final String content;
  final String messageType;
  final List<String> mediaUrls;
  final DateTime? createdAt;
  final bool revoked;
  final String? replyPreview;

  const ChatMessage({
    required this.messageId,
    required this.conversationId,
    this.senderId = 0,
    this.senderName = '',
    this.avatarUrl,
    this.content = '',
    this.messageType = 'TEXT',
    this.mediaUrls = const [],
    this.createdAt,
    this.revoked = false,
    this.replyPreview,
  });

  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    int conversationId = 0,
  }) => ChatMessage(
    messageId: J.intOr(json['message_id']),
    conversationId: J.intOr(json['conversation_id'], conversationId),
    senderId: J.intOr(json['sender_id']),
    senderName: J.stringOr(json['sender_name']),
    avatarUrl: J.asString(json['avatar_url']),
    content: J.stringOr(json['content']),
    messageType: J.stringOr(json['message_type'], 'TEXT'),
    mediaUrls: J.asList(json['media_urls']).map((v) => v.toString()).toList(),
    createdAt: J.asDate(json['created_at']),
    revoked: J.asBool(json['revoked'] ?? json['is_revoked']),
    replyPreview: J.asString(
      J.asMap(json['reply_to_message'])?['content_preview'],
    ),
  );

  String get preview => revoked
      ? 'Tin nhắn đã thu hồi'
      : content.isNotEmpty
      ? content
      : switch (messageType) {
          'IMAGE' => 'Ảnh',
          'VIDEO' => 'Video',
          _ => 'Tệp đính kèm',
        };

  ChatMessage asRevoked() => ChatMessage(
    messageId: messageId,
    conversationId: conversationId,
    senderId: senderId,
    senderName: senderName,
    avatarUrl: avatarUrl,
    createdAt: createdAt,
    revoked: true,
  );

  @override
  List<Object?> get props => [
    messageId,
    conversationId,
    senderId,
    senderName,
    content,
    messageType,
    mediaUrls,
    createdAt,
    revoked,
    replyPreview,
  ];
}

class ChatConversation extends Equatable {
  final int conversationId;
  final String title;
  final String? avatarUrl;
  final String type;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime? updatedAt;
  final List<AuthorModel> members;

  const ChatConversation({
    required this.conversationId,
    required this.title,
    this.avatarUrl,
    this.type = 'DIRECT',
    this.lastMessage,
    this.unreadCount = 0,
    this.updatedAt,
    this.members = const [],
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json, {int? myId}) {
    final members = J.list(json['members'], AuthorModel.fromJson);
    final peers = members.where((m) => m.userId != myId).toList();
    final isDirect = J.stringOr(json['type'], 'DIRECT') == 'DIRECT';
    final peer = isDirect && peers.isNotEmpty ? peers.first : null;
    final id = J.intOr(json['conversation_id']);
    final last = J.asMap(json['last_message']);
    return ChatConversation(
      conversationId: id,
      title: J.stringOr(
        json['display_name'] ?? peer?.fullName ?? json['name'],
        'Cuộc trò chuyện',
      ),
      avatarUrl: J.asString(
        json['display_avatar_url'] ?? peer?.avatarUrl ?? json['avatar_url'],
      ),
      type: J.stringOr(json['type'], 'DIRECT'),
      lastMessage: last == null
          ? null
          : ChatMessage.fromJson(last, conversationId: id),
      unreadCount: J.intOr(json['unread_count']),
      updatedAt: J.asDate(
        json['updated_at'] ?? last?['created_at'] ?? json['created_at'],
      ),
      members: members,
    );
  }

  AuthorModel? peer(int myId) {
    if (type != 'DIRECT') return null;
    for (final member in members) {
      if (member.userId != myId) return member;
    }
    return null;
  }

  ChatConversation withMembers(List<AuthorModel> value) => ChatConversation(
    conversationId: conversationId,
    title: title,
    avatarUrl: avatarUrl,
    type: type,
    lastMessage: lastMessage,
    unreadCount: unreadCount,
    updatedAt: updatedAt,
    members: value,
  );

  @override
  List<Object?> get props => [
    conversationId,
    title,
    avatarUrl,
    type,
    lastMessage,
    unreadCount,
    updatedAt,
    members,
  ];
}

/// Mở lịch sử đã có, hoặc tạo/lấy hội thoại 1-1 từ hồ sơ một người.
class ChatTarget {
  final ChatConversation? conversation;
  final AuthorModel? user;
  const ChatTarget.conversation(ChatConversation value)
    : conversation = value,
      user = null;
  const ChatTarget.user(AuthorModel value) : user = value, conversation = null;
}
