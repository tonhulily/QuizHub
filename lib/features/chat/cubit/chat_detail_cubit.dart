import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/services/chat_realtime.dart';
import '../../../core/services/social_events.dart';
import '../../../core/services/blocked_users.dart';
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
  final ChatConnection connection;
  final bool sending;
  final bool unconfirmed;
  final bool isTyping;
  final int lastReadMessageId;
  final bool checkingAccess;
  final bool sendRestricted;
  final String restrictionMessage;

  const ChatDetailState({
    this.status = ChatStatus.loading,
    this.conversation,
    this.messages = const [],
    this.after,
    this.hasNext = false,
    this.loadingMore = false,
    this.refreshing = false,
    this.error,
    this.connection = ChatConnection.disconnected,
    this.sending = false,
    this.unconfirmed = false,
    this.isTyping = false,
    this.lastReadMessageId = 0,
    this.checkingAccess = false,
    this.sendRestricted = false,
    this.restrictionMessage =
        'Không thể nhắn tin khi một trong hai người chặn người còn lại.',
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
    ChatConnection? connection,
    bool? sending,
    bool? unconfirmed,
    bool? isTyping,
    int? lastReadMessageId,
    bool? checkingAccess,
    bool? sendRestricted,
    String? restrictionMessage,
  }) => ChatDetailState(
    status: status ?? this.status,
    conversation: conversation ?? this.conversation,
    messages: messages ?? this.messages,
    after: after ?? this.after,
    hasNext: hasNext ?? this.hasNext,
    loadingMore: loadingMore ?? this.loadingMore,
    refreshing: refreshing ?? this.refreshing,
    error: clearError ? null : error ?? this.error,
    connection: connection ?? this.connection,
    sending: sending ?? this.sending,
    unconfirmed: unconfirmed ?? this.unconfirmed,
    isTyping: isTyping ?? this.isTyping,
    lastReadMessageId: lastReadMessageId ?? this.lastReadMessageId,
    checkingAccess: checkingAccess ?? this.checkingAccess,
    sendRestricted: sendRestricted ?? this.sendRestricted,
    restrictionMessage: restrictionMessage ?? this.restrictionMessage,
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
    connection,
    sending,
    unconfirmed,
    isTyping,
    lastReadMessageId,
    checkingAccess,
    sendRestricted,
    restrictionMessage,
  ];
}

class ChatDetailCubit extends Cubit<ChatDetailState> {
  final ChatRepository _repo;
  final ChatTarget target;
  final int myId;
  int _request = 0;
  final ChatRealtime? realtime;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  void Function()? _unwatch;
  Timer? _typingStop;
  Timer? _peerTypingStop;
  Timer? _confirmSync;
  DateTime? _lastTyping;
  int _lastRead = 0;
  int? _watchingId;
  bool _active = true;
  Completer<bool>? _confirmation;
  String? _pendingContent;
  List<String> _pendingMedia = const [];
  Set<int> _baseline = {};
  ApiException? _sendError;
  int _accessRequest = 0;
  int _pendingAfterId = 0;
  final Duration confirmationTimeout;

  ChatDetailCubit(
    this._repo, {
    required this.target,
    required this.myId,
    this.realtime,
    SocialEvents? socialEvents,
    BlockedUsers? blocks,
    this.confirmationTimeout = const Duration(seconds: 10),
  }) : super(
         ChatDetailState(
           conversation: target.conversation,
           connection: realtime?.connection ?? ChatConnection.disconnected,
           checkingAccess: realtime != null,
         ),
       ) {
    final live = realtime;
    if (live != null) {
      _subscriptions.add(live.events.listen(_onEvent));
      _subscriptions.add(
        live.connections.listen((connection) {
          if (isClosed) return;
          emit(
            state.copyWith(
              connection: connection,
              isTyping: connection == ChatConnection.connected
                  ? state.isTyping
                  : false,
              checkingAccess: connection == ChatConnection.connected
                  ? true
                  : state.checkingAccess,
            ),
          );
          if (connection == ChatConnection.connected) {
            _lastRead = 0;
            if (state.status == ChatStatus.loaded && _active) unawaited(load());
          } else if (connection == ChatConnection.disconnected) {
            _completeSend(false);
          }
        }),
      );
      unawaited(live.acquire());
    }
    if (socialEvents != null) {
      _subscriptions.add(
        socialEvents.onChanged.listen((_) => _relationshipChanged()),
      );
    }
    if (blocks != null) {
      _subscriptions.add(
        blocks.onChanged.listen((_) => _relationshipChanged()),
      );
    }
  }

  void _relationshipChanged() {
    if (isClosed) return;
    unawaited(state.sendRestricted ? load() : checkAccess());
  }

  Future<void> load() async {
    if (isClosed) return;
    final request = ++_request;
    emit(
      state.copyWith(
        refreshing: state.status == ChatStatus.loaded,
        clearError: true,
        checkingAccess: realtime != null,
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
      final first = state.status != ChatStatus.loaded || state.messages.isEmpty;
      emit(
        state.copyWith(
          status: ChatStatus.loaded,
          conversation: conversation,
          messages: mergeMessages(state.messages, page.items),
          refreshing: false,
          loadingMore: false,
          after: first ? page.after : state.after,
          hasNext: first ? page.hasNext : state.hasNext,
        ),
      );
      _watch(conversation.conversationId);
      _checkConfirmation();
      _markRead();
      if (conversation.members.isEmpty) {
        await _loadMembers(conversation.conversationId);
      }
      if (!isClosed && request == _request) await checkAccess();
    } on ApiException catch (e) {
      if (isClosed || request != _request) return;
      if (e.isNoMoreData && state.conversation != null) {
        _watch(state.conversation!.conversationId);
        emit(
          state.copyWith(
            status: ChatStatus.loaded,
            refreshing: false,
            hasNext: false,
            clearError: true,
          ),
        );
        await checkAccess();
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
      _restrict(e);
    }
  }

  void _watch(int id) {
    if (_watchingId == id) return;
    _unwatch?.call();
    _watchingId = id;
    _unwatch = realtime?.watchTyping(id);
  }

  void _onEvent(ChatEvent event) {
    if (isClosed ||
        (event.conversationId != 0 &&
            event.conversationId != state.conversation?.conversationId)) {
      return;
    }
    if (state.sendRestricted &&
        event.kind != ChatEventKind.error &&
        event.kind != ChatEventKind.sync) {
      return;
    }
    switch (event.kind) {
      case ChatEventKind.message:
        final message = event.message;
        if (message == null ||
            message.conversationId != state.conversation?.conversationId) {
          return;
        }
        emit(
          state.copyWith(
            messages: mergeMessages(state.messages, [message]),
            isTyping: message.senderId == myId ? state.isTyping : false,
          ),
        );
        _checkConfirmation();
        _markRead();
      case ChatEventKind.read:
        if (event.userId != 0 && event.userId != myId) {
          emit(
            state.copyWith(
              lastReadMessageId: event.readMessageId > state.lastReadMessageId
                  ? event.readMessageId
                  : state.lastReadMessageId,
            ),
          );
        }
      case ChatEventKind.typing:
        if (event.userId == 0 || event.userId == myId) return;
        _peerTypingStop?.cancel();
        emit(state.copyWith(isTyping: event.isTyping));
        if (event.isTyping) {
          _peerTypingStop = Timer(const Duration(seconds: 4), () {
            if (!isClosed) emit(state.copyWith(isTyping: false));
          });
        }
      case ChatEventKind.sync:
        if (_active) unawaited(load());
      case ChatEventKind.error:
        _sendError = event.error;
        _completeSend(false);
        emit(state.copyWith(error: event.error));
        if (event.error != null) _restrict(event.error!);
    }
  }

  void setActive(bool active) {
    _active = active;
    if (active) {
      _markRead();
    } else {
      inputChanged('');
    }
  }

  void _markRead() {
    if (!_active ||
        state.sendRestricted ||
        state.checkingAccess ||
        state.messages.isEmpty ||
        state.connection != ChatConnection.connected) {
      return;
    }
    final message = state.messages.first;
    if (message.messageId == _lastRead || message.senderId == myId) return;
    realtime?.read(message.conversationId, message.messageId);
    _lastRead = message.messageId;
  }

  void inputChanged(String value) {
    final id = state.conversation?.conversationId;
    if (id == null) return;
    _typingStop?.cancel();
    if (value.trim().isEmpty) {
      realtime?.typing(id, false);
      _lastTyping = null;
      return;
    }
    if (state.sendRestricted || state.checkingAccess || !_active) return;
    final now = DateTime.now();
    if (_lastTyping == null ||
        now.difference(_lastTyping!) > const Duration(seconds: 2)) {
      realtime?.typing(id, true);
      _lastTyping = now;
    }
    _typingStop = Timer(
      const Duration(seconds: 2),
      () => realtime?.typing(id, false),
    );
  }

  void _completeSend(bool confirmed) {
    final completion = _confirmation;
    if (completion != null && !completion.isCompleted) {
      completion.complete(confirmed);
    }
  }

  bool _checkConfirmation() {
    if (_pendingContent == null) return false;
    final found = state.messages.any(
      (m) =>
          !_baseline.contains(m.messageId) &&
          m.messageId > _pendingAfterId &&
          m.senderId == myId &&
          m.content == _pendingContent &&
          m.mediaUrls.join('\n') == _pendingMedia.join('\n'),
    );
    if (found) {
      _completeSend(true);
    }
    return found;
  }

  Future<bool> reconcilePending() async {
    await load();
    if (isClosed) return false;
    final found = _checkConfirmation();
    if (found) {
      _pendingContent = null;
      emit(state.copyWith(unconfirmed: false));
    }
    return found;
  }

  Future<ApiException?> send(
    String content, {
    String messageType = 'TEXT',
    List<String> mediaUrls = const [],
    bool allowRetry = false,
  }) async {
    if (state.sendRestricted || state.checkingAccess) {
      return ApiException(
        type: ApiErrorType.forbidden,
        message: state.sendRestricted
            ? state.restrictionMessage
            : 'Đang kiểm tra quyền nhắn tin. Hãy thử lại sau.',
      );
    }
    if (state.unconfirmed && !allowRetry) {
      return const ApiException(
        type: ApiErrorType.validation,
        message: 'Hãy kiểm tra lịch sử và xác nhận trước khi gửi lại.',
      );
    }
    if (state.sending) return null;
    if (state.connection != ChatConnection.connected ||
        state.conversation == null) {
      return const ApiException(
        type: ApiErrorType.noConnection,
        message: 'Chưa kết nối được tin nhắn. Hãy thử lại sau.',
      );
    }
    final text = content.trim();
    if (text.isEmpty && mediaUrls.isEmpty) {
      return const ApiException(
        type: ApiErrorType.validation,
        message: 'Hãy nhập tin nhắn.',
      );
    }
    if (text.length > 2000) {
      return const ApiException(
        type: ApiErrorType.validation,
        message: 'Tin nhắn tối đa 2000 ký tự.',
      );
    }
    _pendingContent = text;
    _pendingMedia = mediaUrls;
    _baseline = state.messages.map((m) => m.messageId).toSet();
    _pendingAfterId = _baseline.fold(0, (a, b) => a > b ? a : b);
    _sendError = null;
    final confirmation = Completer<bool>();
    _confirmation = confirmation;
    emit(state.copyWith(sending: true, unconfirmed: false, clearError: true));
    inputChanged('');
    try {
      realtime!.send(
        conversationId: state.conversation!.conversationId,
        content: text,
        messageType: messageType,
        mediaUrls: mediaUrls,
      );
      _confirmSync = Timer(const Duration(seconds: 1), () {
        if (!isClosed && _active && !confirmation.isCompleted) {
          unawaited(load());
        }
      });
      final confirmed = await confirmation.future.timeout(
        confirmationTimeout,
        onTimeout: () => false,
      );
      if (confirmed) {
        _pendingContent = null;
        return null;
      }
      if (!isClosed) emit(state.copyWith(unconfirmed: _sendError == null));
      return _sendError ??
          const ApiException(
            type: ApiErrorType.timeout,
            message:
                'Chưa xác nhận tin đã gửi. Nội dung được giữ lại; hãy kiểm tra lịch sử trước khi gửi lại.',
          );
    } on ApiException catch (e) {
      _pendingContent = null;
      _restrict(e);
      return e;
    } catch (_) {
      _pendingContent = null;
      return const ApiException(
        type: ApiErrorType.noConnection,
        message: 'Không gửi được tin nhắn. Nội dung vẫn được giữ lại.',
      );
    } finally {
      _confirmSync?.cancel();
      _confirmation = null;
      if (!isClosed) emit(state.copyWith(sending: false));
    }
  }

  @override
  Future<void> close() async {
    inputChanged('');
    _completeSend(false);
    _typingStop?.cancel();
    _peerTypingStop?.cancel();
    _confirmSync?.cancel();
    _unwatch?.call();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    realtime?.release();
    return super.close();
  }

  int? get _peerId {
    final conversation = state.conversation;
    if (conversation?.type != 'DIRECT') return null;
    final known = conversation?.peer(myId)?.userId ?? target.user?.userId;
    if (known != null) return known;
    for (final message in state.messages) {
      if (message.senderId > 0 && message.senderId != myId) {
        return message.senderId;
      }
    }
    return null;
  }

  Future<void> checkAccess() async {
    if (isClosed || realtime == null) return;
    final request = ++_accessRequest;
    final peer = _peerId;
    if (peer == null) {
      emit(state.copyWith(checkingAccess: false));
      _markRead();
      return;
    }
    emit(state.copyWith(checkingAccess: true));
    try {
      final blocked = await _repo.blockedWith(peer);
      if (isClosed || request != _accessRequest) return;
      if (blocked) {
        inputChanged('');
        _sendError = const ApiException(
          type: ApiErrorType.forbidden,
          code: 'USER_BLOCKED',
          message:
              'Không thể nhắn tin khi một trong hai người chặn người còn lại.',
        );
        _completeSend(false);
      }
      emit(
        state.copyWith(
          checkingAccess: false,
          sendRestricted: blocked,
          messages: blocked ? const [] : state.messages,
          hasNext: blocked ? false : state.hasNext,
          lastReadMessageId: blocked ? 0 : state.lastReadMessageId,
          isTyping: blocked ? false : state.isTyping,
          restrictionMessage:
              'Không thể nhắn tin khi một trong hai người chặn người còn lại.',
        ),
      );
      if (!blocked) _markRead();
    } on ApiException catch (e) {
      if (!isClosed && request == _accessRequest) {
        emit(state.copyWith(error: e));
        _restrict(e);
      }
    }
  }

  void _restrict(ApiException error) {
    if (isClosed) return;
    final code = (error.code ?? '').toUpperCase();
    if (error.type != ApiErrorType.forbidden && !code.contains('BLOCK')) return;
    _sendError = error;
    _completeSend(false);
    inputChanged('');
    emit(
      state.copyWith(
        sendRestricted: true,
        messages: const [],
        hasNext: false,
        lastReadMessageId: 0,
        checkingAccess: false,
        isTyping: false,
        restrictionMessage: error.message,
      ),
    );
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
    if (isClosed) return;
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
    if (forEveryone && message.senderId != myId) {
      return const ApiException(
        type: ApiErrorType.forbidden,
        message: 'Chỉ thu hồi được tin nhắn của mình.',
      );
    }
    try {
      await _repo.deleteMessage(message.messageId, forEveryone: forEveryone);
      if (!isClosed) {
        emit(
          state.copyWith(
            messages: forEveryone
                ? [
                    for (final m in state.messages)
                      m.messageId == message.messageId ? m.asRevoked() : m,
                  ]
                : state.messages
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
    final map = {for (final message in old) message.messageId: message};
    for (final message in incoming) {
      // Snapshot REST cũ không được khôi phục nội dung đã thu hồi realtime.
      if (map[message.messageId]?.revoked == true && !message.revoked) continue;
      map[message.messageId] = message;
    }
    return map.values.toList()..sort((a, b) {
      final time = (b.createdAt ?? DateTime(1970)).compareTo(
        a.createdAt ?? DateTime(1970),
      );
      return time == 0 ? b.messageId.compareTo(a.messageId) : time;
    });
  }
}
