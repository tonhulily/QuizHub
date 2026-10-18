import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/services/social_events.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/repositories/friend_repository.dart';

class UserRelationState extends Equatable {
  final RelationshipModel relationship;

  /// Với trạng thái PENDING: true = người kia đã gửi lời mời cho mình,
  /// false = mình đã gửi, null = chưa biết.
  final bool? incoming;
  final bool busy;

  const UserRelationState({
    required this.relationship,
    this.incoming,
    this.busy = false,
  });

  bool get isFriend => relationship.isFriend;
  bool get isPending =>
      !relationship.isFriend && relationship.friendRequestStatus == 'PENDING';

  UserRelationState copyWith({
    RelationshipModel? relationship,
    bool? incoming,
    bool? busy,
  }) => UserRelationState(
    relationship: relationship ?? this.relationship,
    incoming: incoming ?? this.incoming,
    busy: busy ?? this.busy,
  );

  @override
  List<Object?> get props => [relationship, incoming, busy];
}

/// Quan hệ giữa mình và MỘT người dùng khác (nút trên trang cá nhân họ).
///
/// Các hàm hành động trả về [ApiException] nếu lỗi (null nếu thành công).
class UserRelationCubit extends Cubit<UserRelationState> {
  final int userId;
  final FriendRepository _friends;
  final SocialEvents _events;

  UserRelationCubit(
    this._friends,
    this._events, {
    required this.userId,
    required RelationshipModel initial,
  }) : super(UserRelationState(relationship: initial)) {
    if (state.isPending) _resolveDirection();
  }

  /// `GET /users/{id}` chỉ cho biết PENDING, không nói ai gửi: tra danh sách
  /// lời mời đã nhận để biết đây có phải lời mời gửi tới mình không.
  Future<void> _resolveDirection() async {
    try {
      final received = await _friends.receivedRequests(limit: 50);
      if (isClosed) return;
      emit(
        state.copyWith(
          incoming: received.items.any((r) => r.user.userId == userId),
        ),
      );
    } on ApiException {
      // Không rõ hướng thì coi như mình đã gửi (an toàn hơn là hiện nút Xác nhận)
      if (!isClosed) emit(state.copyWith(incoming: false));
    }
  }

  Future<ApiException?> _run(
    Future<void> Function() action,
    RelationshipModel Function(RelationshipModel r) apply, {
    bool? incoming,
  }) async {
    emit(state.copyWith(busy: true));
    try {
      await action();
      emit(
        state.copyWith(
          relationship: apply(state.relationship),
          incoming: incoming,
          busy: false,
        ),
      );
      _events.notifyChanged();
      return null;
    } on ApiException catch (e) {
      emit(state.copyWith(busy: false));
      return e;
    }
  }

  Future<ApiException?> addFriend() async {
    emit(state.copyWith(busy: true));
    try {
      final status = await _friends.sendRequest(userId);
      final accepted = status == 'ACCEPTED';
      emit(
        state.copyWith(
          relationship: state.relationship.copyWith(
            isFriend: accepted,
            friendRequestStatus: accepted ? 'ACCEPTED' : 'PENDING',
          ),
          incoming: false,
          busy: false,
        ),
      );
      _events.notifyChanged();
      return null;
    } on ApiException catch (e) {
      emit(state.copyWith(busy: false));
      return e;
    }
  }

  Future<ApiException?> accept() => _run(
    () => _friends.accept(userId),
    (r) => r.copyWith(isFriend: true, friendRequestStatus: 'ACCEPTED'),
  );

  Future<ApiException?> decline() => _run(
    () => _friends.decline(userId),
    (r) => r.copyWith(friendRequestStatus: 'DECLINED'),
  );

  Future<ApiException?> unfriend() => _run(
    () => _friends.unfriend(userId),
    (r) => r.copyWith(isFriend: false, friendRequestStatus: 'NONE'),
  );

  Future<ApiException?> toggleFollow() {
    final following = state.relationship.isFollowing;
    return _run(
      () => following ? _friends.unfollow(userId) : _friends.follow(userId),
      (r) => r.copyWith(isFollowing: !following),
    );
  }

  Future<ApiException?> block() =>
      _run(() => _friends.block(userId), (r) => const RelationshipModel());
}
