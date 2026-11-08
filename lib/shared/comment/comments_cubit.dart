import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_exception.dart';
import '../../core/services/blocked_users.dart';
import '../../data/models/comment_model.dart';
import '../../data/models/react_result.dart';
import '../../data/repositories/comment_repository.dart';
import '../../data/repositories/reaction_repository.dart';

enum CommentsStatus { loading, loaded, failure }

/// Phản hồi của một bình luận gốc.
class ReplyThread extends Equatable {
  final List<CommentModel> items;
  final String? after;
  final bool hasNext;
  final bool loading;

  const ReplyThread({
    this.items = const [],
    this.after,
    this.hasNext = false,
    this.loading = false,
  });

  ReplyThread copyWith({
    List<CommentModel>? items,
    String? after,
    bool? hasNext,
    bool? loading,
  }) => ReplyThread(
    items: items ?? this.items,
    after: after ?? this.after,
    hasNext: hasNext ?? this.hasNext,
    loading: loading ?? this.loading,
  );

  @override
  List<Object?> get props => [items, after, hasNext, loading];
}

class CommentsState extends Equatable {
  final CommentsStatus status;
  final List<CommentModel> items;
  final String? after;
  final bool hasNext;
  final bool loadingMore;
  final bool sending;
  final ApiException? error;

  /// Bình luận gốc đang được trả lời (null = bình luận mới)
  final CommentModel? replyingTo;

  /// Phản hồi đã tải theo id bình luận gốc
  final Map<int, ReplyThread> threads;

  /// Tổng chênh lệch số bình luận so với lúc mở (để cập nhật PostCard)
  final int countDelta;
  final Map<int, ReactResult> reactions;
  final Set<int> reactingIds;

  const CommentsState({
    this.status = CommentsStatus.loading,
    this.items = const [],
    this.after,
    this.hasNext = false,
    this.loadingMore = false,
    this.sending = false,
    this.error,
    this.replyingTo,
    this.threads = const {},
    this.countDelta = 0,
    this.reactions = const {},
    this.reactingIds = const {},
  });

  CommentsState copyWith({
    CommentsStatus? status,
    List<CommentModel>? items,
    String? after,
    bool? hasNext,
    bool? loadingMore,
    bool? sending,
    ApiException? error,
    bool clearError = false,
    CommentModel? replyingTo,
    bool clearReplyingTo = false,
    Map<int, ReplyThread>? threads,
    int? countDelta,
    Map<int, ReactResult>? reactions,
    Set<int>? reactingIds,
  }) => CommentsState(
    status: status ?? this.status,
    items: items ?? this.items,
    after: after ?? this.after,
    hasNext: hasNext ?? this.hasNext,
    loadingMore: loadingMore ?? this.loadingMore,
    sending: sending ?? this.sending,
    error: clearError ? null : (error ?? this.error),
    replyingTo: clearReplyingTo ? null : (replyingTo ?? this.replyingTo),
    threads: threads ?? this.threads,
    countDelta: countDelta ?? this.countDelta,
    reactions: reactions ?? this.reactions,
    reactingIds: reactingIds ?? this.reactingIds,
  );

  CommentModel withReaction(CommentModel comment) {
    final reaction = reactions[comment.commentId];
    return reaction == null
        ? comment
        : comment.copyWith(
            reactCount: reaction.totalCount,
            reactedByMe: reaction.reacted,
          );
  }

  @override
  List<Object?> get props => [
    status,
    items,
    after,
    hasNext,
    loadingMore,
    sending,
    error,
    replyingTo,
    threads,
    countDelta,
    reactions,
    reactingIds,
  ];
}

/// Logic bình luận dùng chung cho POST / SESSION / QUESTION.
class CommentsCubit extends Cubit<CommentsState> {
  final CommentRepository _repo;
  final ReactionRepository _reactions;
  final BlockedUsers? _blocks;
  StreamSubscription<void>? _blocksSub;
  int _loadRequest = 0;
  final TargetType targetType;
  final int targetId;

  CommentsCubit(
    this._repo, {
    required ReactionRepository reactions,
    BlockedUsers? blocks,
    required this.targetType,
    required this.targetId,
  }) : _reactions = reactions,
       _blocks = blocks,
       super(const CommentsState()) {
    _blocksSub = blocks?.onChanged.listen((_) => unawaited(load()));
  }

  Future<ApiException?> toggleLike(CommentModel comment) async {
    final id = comment.commentId;
    if (_blocks?.contains(comment.author?.userId) ?? false) {
      return BlockedUsers.unavailable;
    }
    if (isClosed ||
        comment.hidden ||
        comment.author == null ||
        state.reactingIds.contains(id)) {
      return null;
    }
    final before = state.reactions[id];
    final current = state.withReaction(comment);
    final next = !current.reactedByMe;
    emit(
      state.copyWith(
        reactions: {
          ...state.reactions,
          id: ReactResult(
            myReaction: next ? 'LIKE' : null,
            totalCount: (current.reactCount + (next ? 1 : -1)).clamp(
              0,
              1 << 30,
            ),
          ),
        },
        reactingIds: {...state.reactingIds, id},
      ),
    );
    try {
      final result = await _reactions.toggleLike(
        targetType: TargetType.comment,
        targetId: id,
      );
      if (isClosed) return null;
      emit(
        state.copyWith(
          reactions: {...state.reactions, id: result},
          reactingIds: {...state.reactingIds}..remove(id),
        ),
      );
      return null;
    } on ApiException catch (error) {
      if (!isClosed) {
        final restored = {...state.reactions}..remove(id);
        if (before != null) restored[id] = before;
        emit(
          state.copyWith(
            reactions: restored,
            reactingIds: {...state.reactingIds}..remove(id),
          ),
        );
      }
      return error;
    }
  }

  Future<void> load() async {
    if (isClosed) return;
    final request = ++_loadRequest;
    emit(
      CommentsState(
        countDelta: state.countDelta,
        reactions: state.reactions,
        reactingIds: state.reactingIds,
        sending: state.sending,
      ),
    );
    try {
      final page = await _repo.list(targetType: targetType, targetId: targetId);
      if (isClosed || request != _loadRequest) return;
      emit(
        state.copyWith(
          status: CommentsStatus.loaded,
          items: page.items,
          after: page.after,
          hasNext: page.hasNext,
        ),
      );
    } on ApiException catch (e) {
      if (isClosed || request != _loadRequest) return;
      // 9994 = hết dữ liệu -> danh sách rỗng, không phải lỗi
      if (e.isNoMoreData) {
        emit(state.copyWith(status: CommentsStatus.loaded));
      } else {
        emit(state.copyWith(status: CommentsStatus.failure, error: e));
      }
    }
  }

  Future<void> loadMore() async {
    if (!state.hasNext || state.loadingMore) return;
    final request = _loadRequest;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _repo.list(
        targetType: targetType,
        targetId: targetId,
        after: state.after,
      );
      if (isClosed || request != _loadRequest) return;
      emit(
        state.copyWith(
          items: [...state.items, ...page.items],
          after: page.after,
          hasNext: page.hasNext,
          loadingMore: false,
        ),
      );
    } on ApiException {
      if (!isClosed) emit(state.copyWith(loadingMore: false));
    }
  }

  /// Mở / tải thêm phản hồi của một bình luận gốc.
  Future<void> loadReplies(CommentModel parent) async {
    if (isClosed || (_blocks?.contains(parent.author?.userId) ?? false)) return;
    final request = _loadRequest;
    final current = state.threads[parent.commentId] ?? const ReplyThread();
    if (current.loading) return;

    // Lần đầu: dùng sẵn replies server trả kèm nếu có
    if (current.items.isEmpty &&
        parent.replies.isNotEmpty &&
        current.after == null) {
      _setThread(
        parent.commentId,
        ReplyThread(
          items: parent.replies,
          hasNext: parent.replyCount > parent.replies.length,
        ),
      );
      if (parent.replyCount <= parent.replies.length) return;
    }

    final thread = state.threads[parent.commentId] ?? const ReplyThread();
    _setThread(parent.commentId, thread.copyWith(loading: true));
    try {
      final page = await _repo.list(
        targetType: targetType,
        targetId: targetId,
        parentCommentId: parent.commentId,
        newestFirst: false,
        after: thread.items.isEmpty ? null : thread.after,
      );
      if (isClosed || request != _loadRequest) return;
      final merged = thread.items.isEmpty
          ? page.items
          : [...thread.items, ...page.items];
      _setThread(
        parent.commentId,
        ReplyThread(items: merged, after: page.after, hasNext: page.hasNext),
      );
    } on ApiException {
      _setThread(parent.commentId, thread.copyWith(loading: false));
    }
  }

  void _setThread(int parentId, ReplyThread thread) {
    if (isClosed) return;
    emit(state.copyWith(threads: {...state.threads, parentId: thread}));
  }

  void startReply(CommentModel comment) {
    if (isClosed || (_blocks?.contains(comment.author?.userId) ?? false)) {
      return;
    }
    // Chỉ cho 2 cấp: trả lời 1 phản hồi => gắn vào bình luận gốc
    final rootId = comment.parentCommentId;
    final root = rootId == null
        ? comment
        : state.items.firstWhere(
            (c) => c.commentId == rootId,
            orElse: () => comment,
          );
    emit(state.copyWith(replyingTo: root));
  }

  void cancelReply() => emit(state.copyWith(clearReplyingTo: true));

  /// Gửi bình luận. Trả về lỗi (nếu có) để UI hiển thị.
  Future<ApiException?> send(String content) async {
    if (isClosed) return null;
    if (_blocks?.contains(state.replyingTo?.author?.userId) ?? false) {
      return BlockedUsers.unavailable;
    }
    if (state.sending) return null;
    final parent = state.replyingTo;
    emit(state.copyWith(sending: true));
    try {
      final created = await _repo.create(
        targetType: targetType,
        targetId: targetId,
        content: content.trim(),
        parentCommentId: parent?.commentId,
      );
      if (isClosed) return null;
      if (parent == null) {
        emit(
          state.copyWith(
            items: [created, ...state.items],
            sending: false,
            countDelta: state.countDelta + 1,
          ),
        );
      } else {
        final thread = state.threads[parent.commentId] ?? const ReplyThread();
        final items = state.items
            .map(
              (c) => c.commentId == parent.commentId
                  ? c.copyWith(replyCount: c.replyCount + 1)
                  : c,
            )
            .toList();
        emit(
          state.copyWith(
            items: items,
            threads: {
              ...state.threads,
              parent.commentId: thread.copyWith(
                items: [...thread.items, created],
              ),
            },
            sending: false,
            clearReplyingTo: true,
            countDelta: state.countDelta + 1,
          ),
        );
      }
      return null;
    } on ApiException catch (e) {
      if (!isClosed) emit(state.copyWith(sending: false));
      return e;
    }
  }

  /// Xoá bình luận của chính mình.
  Future<ApiException?> delete(CommentModel comment) async {
    try {
      await _repo.delete(comment.commentId);
    } on ApiException catch (e) {
      return e;
    }
    final parentId = comment.parentCommentId;
    if (isClosed) return null;
    if (parentId == null) {
      final threads = {...state.threads}..remove(comment.commentId);
      emit(
        state.copyWith(
          items: state.items
              .where((c) => c.commentId != comment.commentId)
              .toList(),
          threads: threads,
          countDelta: state.countDelta - (1 + comment.replyCount),
        ),
      );
    } else {
      final thread = state.threads[parentId];
      emit(
        state.copyWith(
          items: state.items
              .map(
                (c) => c.commentId == parentId
                    ? c.copyWith(
                        replyCount: (c.replyCount - 1).clamp(0, 1 << 30),
                      )
                    : c,
              )
              .toList(),
          threads: thread == null
              ? null
              : {
                  ...state.threads,
                  parentId: thread.copyWith(
                    items: thread.items
                        .where((c) => c.commentId != comment.commentId)
                        .toList(),
                  ),
                },
          countDelta: state.countDelta - 1,
        ),
      );
    }
    return null;
  }

  @override
  Future<void> close() async {
    await _blocksSub?.cancel();
    return super.close();
  }
}
