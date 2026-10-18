import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/services/social_events.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/models/social_models.dart';
import '../../../data/repositories/friend_repository.dart';
import '../../../data/repositories/user_search_repository.dart';

enum SectionStatus { loading, loaded, failure }

class FriendsState extends Equatable {
  final SectionStatus suggestionsStatus;
  final SectionStatus requestsStatus;
  final SectionStatus friendsStatus;

  final List<UserSearchResult> suggestions;
  final List<FriendRequestModel> received;
  final List<FriendRequestModel> sent;
  final List<FriendModel> friends;

  /// Id những người đang có thao tác chạy dở (khoá nút của họ).
  final Set<int> busy;

  const FriendsState({
    this.suggestionsStatus = SectionStatus.loading,
    this.requestsStatus = SectionStatus.loading,
    this.friendsStatus = SectionStatus.loading,
    this.suggestions = const [],
    this.received = const [],
    this.sent = const [],
    this.friends = const [],
    this.busy = const {},
  });

  FriendsState copyWith({
    SectionStatus? suggestionsStatus,
    SectionStatus? requestsStatus,
    SectionStatus? friendsStatus,
    List<UserSearchResult>? suggestions,
    List<FriendRequestModel>? received,
    List<FriendRequestModel>? sent,
    List<FriendModel>? friends,
    Set<int>? busy,
  }) => FriendsState(
    suggestionsStatus: suggestionsStatus ?? this.suggestionsStatus,
    requestsStatus: requestsStatus ?? this.requestsStatus,
    friendsStatus: friendsStatus ?? this.friendsStatus,
    suggestions: suggestions ?? this.suggestions,
    received: received ?? this.received,
    sent: sent ?? this.sent,
    friends: friends ?? this.friends,
    busy: busy ?? this.busy,
  );

  @override
  List<Object?> get props => [
    suggestionsStatus,
    requestsStatus,
    friendsStatus,
    suggestions,
    received,
    sent,
    friends,
    busy,
  ];
}

/// Logic tab Bạn bè: gợi ý, lời mời (nhận / đã gửi), danh sách bạn bè.
///
/// Các hàm hành động trả về [ApiException] nếu lỗi (hoặc null nếu thành công)
/// để màn hình tự hiển thị thông báo, giống `CommentsCubit`.
class FriendsCubit extends Cubit<FriendsState> {
  static const int _pageSize = 50;

  final FriendRepository _friends;
  final UserSearchRepository _search;
  final SocialEvents _events;

  /// Hồ sơ của mình (để gợi ý đúng vai trò và loại chính mình).
  final ProfileModel? Function() _me;

  late final StreamSubscription<void> _sub;

  /// Gợi ý đã bị người dùng bấm "Gỡ" trong phiên này (không hiện lại khi tải).
  final Set<int> _dismissed = {};

  FriendsCubit(this._friends, this._search, this._events, this._me)
    : super(const FriendsState()) {
    // Trang cá nhân người khác vừa đổi quan hệ -> tải lại im lặng
    _sub = _events.onChanged.listen((_) => load(silent: true));
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) emit(const FriendsState());
    // Gợi ý cần biết ai đã là bạn / đã có lời mời nên tải sau hai danh sách này
    await Future.wait([_loadRequests(), _loadFriends()]);
    await _loadSuggestions();
  }

  /// Id những người đã có quan hệ (bạn, lời mời nhận / gửi) đang có trong state.
  Set<int>? _relatedIds() {
    // Nếu một trong các danh sách tải lỗi thì để repository tự tải lại cho chắc
    if (state.friendsStatus != SectionStatus.loaded ||
        state.requestsStatus != SectionStatus.loaded) {
      return null;
    }
    return {
      for (final f in state.friends) f.userId,
      for (final r in state.received) r.user.userId,
      for (final r in state.sent) r.user.userId,
    };
  }

  Future<void> _loadRequests() async {
    try {
      final received = _friends.receivedRequests(limit: _pageSize);
      final sent = _friends.sentRequests(limit: _pageSize);
      final r = await received;
      final s = await sent;
      if (isClosed) return;
      emit(
        state.copyWith(
          requestsStatus: SectionStatus.loaded,
          received: r.items,
          sent: s.items,
        ),
      );
    } on ApiException {
      if (!isClosed) {
        emit(state.copyWith(requestsStatus: SectionStatus.failure));
      }
    }
  }

  Future<void> _loadFriends() async {
    try {
      final page = await _friends.friends(limit: _pageSize);
      if (isClosed) return;
      emit(
        state.copyWith(
          friendsStatus: SectionStatus.loaded,
          friends: page.items,
        ),
      );
    } on ApiException {
      if (!isClosed) emit(state.copyWith(friendsStatus: SectionStatus.failure));
    }
  }

  Future<void> _loadSuggestions() async {
    final me = _me();
    if (me == null) {
      emit(state.copyWith(suggestionsStatus: SectionStatus.failure));
      return;
    }
    try {
      final list = await _search.suggestions(
        myUserId: me.userId,
        myRole: me.role,
        // Đã tải ở bước trước: không gọi lại bạn bè / lời mời
        alreadyRelated: _relatedIds(),
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          suggestionsStatus: SectionStatus.loaded,
          suggestions: [
            for (final u in list)
              if (!_dismissed.contains(u.userId)) u,
          ],
        ),
      );
    } on ApiException {
      if (!isClosed) {
        emit(state.copyWith(suggestionsStatus: SectionStatus.failure));
      }
    }
  }

  /// Lấy lại một đoạn gợi ý khác (nút "Làm mới").
  Future<void> refreshSuggestions() async {
    emit(state.copyWith(suggestionsStatus: SectionStatus.loading));
    await _loadSuggestions();
  }

  // ---------------- Hành động ----------------

  void _setBusy(int id, bool busy) => emit(
    state.copyWith(
      busy: busy ? {...state.busy, id} : ({...state.busy}..remove(id)),
    ),
  );

  /// Gửi lời mời cho một người trong danh sách gợi ý.
  Future<ApiException?> sendRequest(UserSearchResult user) async {
    _setBusy(user.userId, true);
    try {
      final status = await _friends.sendRequest(user.userId);
      emit(
        state.copyWith(
          suggestions: state.suggestions
              .where((u) => u.userId != user.userId)
              .toList(),
          sent: status == 'ACCEPTED'
              ? state.sent
              : [
                  FriendRequestModel(
                    user: user.asAuthor,
                    sentByMe: true,
                    createdAt: DateTime.now(),
                  ),
                  ...state.sent,
                ],
        ),
      );
      // Người kia đã gửi trước -> server tự thành bạn
      if (status == 'ACCEPTED') await _loadFriends();
      return null;
    } on ApiException catch (e) {
      return e;
    } finally {
      _setBusy(user.userId, false);
    }
  }

  Future<ApiException?> accept(FriendRequestModel request) async {
    final id = request.user.userId;
    _setBusy(id, true);
    try {
      await _friends.accept(id);
      emit(
        state.copyWith(
          received: state.received.where((r) => r.user.userId != id).toList(),
          friends: [
            FriendModel(
              userId: id,
              fullName: request.user.fullName,
              avatarUrl: request.user.avatarUrl,
              frameUrl: request.user.frameUrl,
              friendsSince: DateTime.now(),
              mutualFriendsCount: request.mutualFriendsCount,
            ),
            ...state.friends,
          ],
        ),
      );
      return null;
    } on ApiException catch (e) {
      return e;
    } finally {
      _setBusy(id, false);
    }
  }

  Future<ApiException?> decline(FriendRequestModel request) async {
    final id = request.user.userId;
    _setBusy(id, true);
    try {
      await _friends.decline(id);
      emit(
        state.copyWith(
          received: state.received.where((r) => r.user.userId != id).toList(),
        ),
      );
      return null;
    } on ApiException catch (e) {
      return e;
    } finally {
      _setBusy(id, false);
    }
  }

  Future<ApiException?> unfriend(FriendModel friend) async {
    _setBusy(friend.userId, true);
    try {
      await _friends.unfriend(friend.userId);
      emit(
        state.copyWith(
          friends: state.friends
              .where((f) => f.userId != friend.userId)
              .toList(),
        ),
      );
      return null;
    } on ApiException catch (e) {
      return e;
    } finally {
      _setBusy(friend.userId, false);
    }
  }

  /// Bấm "Gỡ" ở một gợi ý: ẩn khỏi danh sách (chỉ trong phiên này).
  void dismissSuggestion(int userId) {
    _dismissed.add(userId);
    emit(
      state.copyWith(
        suggestions: state.suggestions
            .where((u) => u.userId != userId)
            .toList(),
      ),
    );
  }

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
