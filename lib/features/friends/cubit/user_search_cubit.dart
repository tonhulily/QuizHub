import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/social_models.dart';
import '../../../data/repositories/user_search_repository.dart';

enum UserSearchStatus { idle, loading, loaded, failure }

class UserSearchState extends Equatable {
  final String query;
  final UserSearchStatus status;
  final List<UserSearchResult> items;
  final int totalHits;
  final bool hasNext;
  final int? nextOffset;
  final bool loadingMore;
  final ApiException? error;

  /// Đang tìm theo email (tối đa 1 kết quả, không phân trang).
  final bool emailMode;

  const UserSearchState({
    this.query = '',
    this.status = UserSearchStatus.idle,
    this.items = const [],
    this.totalHits = 0,
    this.hasNext = false,
    this.nextOffset,
    this.loadingMore = false,
    this.error,
    this.emailMode = false,
  });

  UserSearchState copyWith({
    String? query,
    UserSearchStatus? status,
    List<UserSearchResult>? items,
    int? totalHits,
    bool? hasNext,
    int? nextOffset,
    bool? loadingMore,
    ApiException? error,
    bool? emailMode,
  }) => UserSearchState(
    query: query ?? this.query,
    status: status ?? this.status,
    items: items ?? this.items,
    totalHits: totalHits ?? this.totalHits,
    hasNext: hasNext ?? this.hasNext,
    nextOffset: nextOffset ?? this.nextOffset,
    loadingMore: loadingMore ?? this.loadingMore,
    error: error,
    emailMode: emailMode ?? this.emailMode,
  );

  @override
  List<Object?> get props => [
    query,
    status,
    items,
    totalHits,
    hasNext,
    nextOffset,
    loadingMore,
    error,
    emailMode,
  ];
}

/// Tìm người dùng theo tên / mã SV-GV / email, có debounce và phân trang.
class UserSearchCubit extends Cubit<UserSearchState> {
  static const _pageSize = 20;

  final UserSearchRepository _repo;
  final Duration debounce;
  Timer? _timer;

  /// Tăng mỗi lần bắt đầu tìm; kết quả của lần cũ bị bỏ qua.
  int _seq = 0;

  UserSearchCubit(
    this._repo, {
    this.debounce = const Duration(milliseconds: 400),
  }) : super(const UserSearchState());

  void onQueryChanged(String raw) {
    _timer?.cancel();
    final q = raw.trim();
    if (q.isEmpty) {
      _seq++;
      emit(const UserSearchState());
      return;
    }
    emit(state.copyWith(query: q, status: UserSearchStatus.loading));
    _timer = Timer(debounce, () => _search(q));
  }

  /// Tìm ngay (không chờ debounce), vd khi bấm nút tìm trên bàn phím.
  Future<void> submit(String raw) {
    _timer?.cancel();
    final q = raw.trim();
    if (q.isEmpty) return Future.value();
    return _search(q);
  }

  Future<void> _search(String q) async {
    final seq = ++_seq;
    final emailMode = UserSearchRepository.looksLikeEmail(q);
    emit(
      state.copyWith(
        query: q,
        status: UserSearchStatus.loading,
        items: const [],
        emailMode: emailMode,
      ),
    );
    try {
      if (emailMode) {
        final found = await _repo.findByEmail(q);
        if (seq != _seq || isClosed) return;
        emit(
          state.copyWith(
            status: UserSearchStatus.loaded,
            items: found == null ? const [] : [found],
            totalHits: found == null ? 0 : 1,
            hasNext: false,
          ),
        );
      } else {
        final page = await _repo.searchUsers(q, limit: _pageSize);
        if (seq != _seq || isClosed) return;
        emit(
          state.copyWith(
            status: UserSearchStatus.loaded,
            items: page.items,
            totalHits: page.totalHits,
            hasNext: page.hasNext,
            nextOffset: page.nextOffset,
          ),
        );
      }
    } on ApiException catch (e) {
      if (seq != _seq || isClosed) return;
      emit(state.copyWith(status: UserSearchStatus.failure, error: e));
    }
  }

  Future<void> loadMore() async {
    if (!state.hasNext ||
        state.loadingMore ||
        state.status != UserSearchStatus.loaded ||
        state.emailMode) {
      return;
    }
    final seq = _seq;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _repo.searchUsers(
        state.query,
        after: state.nextOffset,
        limit: _pageSize,
      );
      if (seq != _seq || isClosed) return;
      emit(
        state.copyWith(
          items: [...state.items, ...page.items],
          hasNext: page.hasNext,
          nextOffset: page.nextOffset,
          loadingMore: false,
        ),
      );
    } on ApiException {
      if (seq == _seq && !isClosed) emit(state.copyWith(loadingMore: false));
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
