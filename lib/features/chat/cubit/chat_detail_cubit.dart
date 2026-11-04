import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/chat_models.dart';
import '../../../data/repositories/chat_repository.dart';

enum ChatStatus { loading, loaded, failure }

class ChatDetailState extends Equatable {
  final ChatStatus status;
  final ChatConversation? conversation;
  final List<ChatMessage> messages;
  final String? after;
  final bool hasNext;
  final bool loadingMore;
  final bool refreshing;
  final ApiException? error;

  const ChatDetailState({
    this.status = ChatStatus.loading,
    this.conversation,
    this.messages = const [],
    this.after,
    this.hasNext = false,
    this.loadingMore = false,
    this.refreshing = false,
    this.error,
  });

  ChatDetailState copyWith({
    ChatStatus? status,
    ChatConversation? conversation,
    List<ChatMessage>? messages,
    String? after,
    bool? hasNext,
    bool? loadingMore,
    bool? refreshing,
    ApiException? error,
    bool clearError = false,
  }) => ChatDetailState(
    status: status ?? this.status,
    conversation: conversation ?? this.conversation,
    messages: messages ?? this.messages,
    after: after ?? this.after,
    hasNext: hasNext ?? this.hasNext,
    loadingMore: loadingMore ?? this.loadingMore,
    refreshing: refreshing ?? this.refreshing,
    error: clearError ? null : error ?? this.error,
  );

  @override
  List<Object?> get props => [
    status,
    conversation,
    messages,
    after,
    hasNext,
    loadingMore,
    refreshing,
    error,
  ];
}

class ChatDetailCubit extends Cubit<ChatDetailState> {
  final ChatRepository _repo;
  final ChatTarget target;
  final int myId;
  int _request = 0;

  ChatDetailCubit(this._repo, {required this.target, required this.myId})
    : super(ChatDetailState(conversation: target.conversation));

  Future<void> load() async {
    final request = ++_request;
    emit(
      state.copyWith(
        refreshing: state.status == ChatStatus.loaded,
        clearError: true,
      ),
    );
    try {
      final conversation =
          state.conversation ??
          await _repo.direct(target.user!.userId, myId: myId);
      if (isClosed || request != _request) return;
      emit(state.copyWith(conversation: conversation));
      final page = await _repo.messages(conversation.conversationId);
      if (isClosed || request != _request) return;
      final first = state.status != ChatStatus.loaded;
      emit(
        ChatDetailState(
          status: ChatStatus.loaded,
          conversation: conversation,
          messages: mergeMessages(
            first ? const [] : state.messages,
            page.items,
          ),
          after: first ? page.after : state.after,
          hasNext: first ? page.hasNext : state.hasNext,
        ),
      );
      if (conversation.members.isEmpty) {
        _loadMembers(conversation.conversationId);
      }
    } on ApiException catch (e) {
      if (isClosed || request != _request) return;
      if (e.isNoMoreData && state.conversation != null) {
        emit(
          state.copyWith(
            status: ChatStatus.loaded,
            refreshing: false,
            hasNext: false,
            clearError: true,
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: state.status == ChatStatus.loaded
              ? ChatStatus.loaded
              : ChatStatus.failure,
          error: e,
          refreshing: false,
        ),
      );
    }
  }

  Future<void> _loadMembers(int id) async {
    try {
      final members = await _repo.members(id);
      if (isClosed || state.conversation?.conversationId != id) return;
      emit(
        state.copyWith(conversation: state.conversation!.withMembers(members)),
      );
    } on ApiException {
      // Lịch sử vẫn xem được nếu backend giới hạn endpoint thành viên.
    }
  }

  Future<void> loadMore() async {
    final conversation = state.conversation;
    if (conversation == null ||
        !state.hasNext ||
        state.loadingMore ||
        state.refreshing) {
      return;
    }
    final request = _request;
    emit(state.copyWith(loadingMore: true, clearError: true));
    try {
      final page = await _repo.messages(
        conversation.conversationId,
        after: state.after,
      );
      if (isClosed || request != _request) return;
      emit(
        state.copyWith(
          messages: mergeMessages(state.messages, page.items),
          after: page.after,
          hasNext: page.hasNext,
          loadingMore: false,
        ),
      );
    } on ApiException catch (e) {
      if (isClosed || request != _request) return;
      emit(
        state.copyWith(
          loadingMore: false,
          hasNext: e.isNoMoreData ? false : state.hasNext,
          error: e.isNoMoreData ? null : e,
        ),
      );
    }
  }

  Future<ApiException?> delete(
    ChatMessage message, {
    bool forEveryone = false,
  }) async {
    try {
      await _repo.deleteMessage(message.messageId, forEveryone: forEveryone);
      if (!isClosed) {
        emit(
          state.copyWith(
            messages: state.messages
                .where((m) => m.messageId != message.messageId)
                .toList(),
          ),
        );
        await load();
      }
      return null;
    } on ApiException catch (e) {
      return e;
    }
  }

  static List<ChatMessage> mergeMessages(
    List<ChatMessage> old,
    List<ChatMessage> incoming,
  ) {
    final map = {
      for (final message in [...old, ...incoming]) message.messageId: message,
    };
    return map.values.toList()..sort((a, b) {
      final time = (b.createdAt ?? DateTime(1970)).compareTo(
        a.createdAt ?? DateTime(1970),
      );
      return time == 0 ? b.messageId.compareTo(a.messageId) : time;
    });
  }
}
