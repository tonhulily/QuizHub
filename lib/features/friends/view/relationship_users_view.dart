import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/paged_cubit.dart';
import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/design_system/component_tokens.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/social_events.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/paged_list.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/social_models.dart';
import '../../../data/repositories/friend_repository.dart';
import '../../../di/locator.dart';
import '../../../features/profile/cubit/profile_cubit.dart';
import '../widgets/person_card.dart';

enum RelationshipListKind { followers, following, blocked }

/// Danh sách followers, following hoặc tài khoản đã chặn của người dùng hiện tại.
class RelationshipUsersView extends StatefulWidget {
  final RelationshipListKind kind;

  const RelationshipUsersView({super.key, required this.kind});

  @override
  State<RelationshipUsersView> createState() => _RelationshipUsersViewState();
}

class _RelationshipUsersViewState extends State<RelationshipUsersView> {
  late final PagedCubit<RelationshipUserModel> _users = PagedCubit((after) {
    final repo = getIt<FriendRepository>();
    return switch (widget.kind) {
      RelationshipListKind.followers => repo.followers(after: after),
      RelationshipListKind.following => repo.following(after: after),
      RelationshipListKind.blocked => repo.blockedUsers(after: after),
    };
  })..load();

  final Set<int> _busy = {};

  String get _title => switch (widget.kind) {
    RelationshipListKind.followers => 'Người theo dõi',
    RelationshipListKind.following => 'Đang theo dõi',
    RelationshipListKind.blocked => 'Người đã chặn',
  };

  @override
  void dispose() {
    _users.close();
    super.dispose();
  }

  void _openProfile(int userId) {
    final myId = context.read<ProfileCubit>().state.profile?.userId;
    Navigator.of(context).pushNamed(
      userId == myId ? AppRoutes.myProfile : AppRoutes.userProfile,
      arguments: userId,
    );
  }

  Future<void> _removeRelationship(RelationshipUserModel user) async {
    final isBlocked = widget.kind == RelationshipListKind.blocked;
    final action = isBlocked ? 'bỏ chặn' : 'bỏ theo dõi';
    final ok = await showConfirmDialog(
      context,
      title: '${isBlocked ? 'Bỏ chặn' : 'Bỏ theo dõi'} ${user.fullName}?',
      message: 'Bạn có chắc muốn $action ${user.fullName}?',
      confirmLabel: isBlocked ? 'Bỏ chặn' : 'Bỏ theo dõi',
      destructive: true,
    );
    if (!ok || !mounted) return;

    setState(() => _busy.add(user.userId));
    try {
      final repo = getIt<FriendRepository>();
      if (isBlocked) {
        await repo.unblock(user.userId);
      } else {
        await repo.unfollow(user.userId);
      }
      if (!mounted) return;
      _users.removeWhere((item) => item.userId == user.userId);
      getIt<SocialEvents>().notifyChanged();
      AppFeedback.success(
        context,
        isBlocked
            ? 'Đã bỏ chặn ${user.fullName}'
            : 'Đã bỏ theo dõi ${user.fullName}',
      );
    } on ApiException catch (e) {
      if (mounted) AppFeedback.error(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(user.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBlocked = widget.kind == RelationshipListKind.blocked;
    final canUnfollow = widget.kind == RelationshipListKind.following;

    return BlocProvider.value(
      value: _users,
      child: Scaffold(
        backgroundColor: AppColors.backgroundSecondary,
        appBar: AppBar(title: Text(_title)),
        body: PagedListView<RelationshipUserModel>(
          padding: EdgeInsets.zero,
          itemSpacing: ComponentTokens.postGap,
          onRefresh: _users.refresh,
          emptyView: EmptyView(
            icon: isBlocked ? AppIcons.lock : AppIcons.friends,
            title: switch (widget.kind) {
              RelationshipListKind.followers => 'Chưa có người theo dõi',
              RelationshipListKind.following => 'Bạn chưa theo dõi ai',
              RelationshipListKind.blocked => 'Bạn chưa chặn ai',
            },
            compact: true,
          ),
          itemBuilder: (context, user) => PersonCard(
            key: ValueKey('${widget.kind.name}_${user.userId}'),
            name: user.fullName,
            avatarUrl: user.avatarUrl,
            frameUrl: user.frameUrl,
            onTap: isBlocked ? null : () => _openProfile(user.userId),
            primaryLabel: isBlocked
                ? 'Bỏ chặn'
                : canUnfollow
                ? 'Bỏ theo dõi'
                : null,
            onPrimary: isBlocked || canUnfollow
                ? () => _removeRelationship(user)
                : null,
            busy: _busy.contains(user.userId),
          ),
        ),
      ),
    );
  }
}
