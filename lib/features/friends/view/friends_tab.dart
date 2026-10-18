import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/social_events.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/social_models.dart';
import '../../../data/repositories/friend_repository.dart';
import '../../../data/repositories/user_search_repository.dart';
import '../../../di/locator.dart';
import '../../profile/cubit/profile_cubit.dart';
import '../cubit/friends_cubit.dart';
import '../widgets/person_card.dart';

enum _Segment { suggestions, requests, friends }

/// Tab Bạn bè kiểu Facebook: thanh tìm kiếm, 3 nhóm (Gợi ý / Lời mời / Bạn bè).
class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  late final FriendsCubit _cubit;
  _Segment _segment = _Segment.suggestions;

  @override
  void initState() {
    super.initState();
    final profileCubit = context.read<ProfileCubit>();
    _cubit = FriendsCubit(
      getIt<FriendRepository>(),
      getIt<UserSearchRepository>(),
      getIt<SocialEvents>(),
      () => profileCubit.state.profile,
    )..load();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  void _openProfile(int userId) {
    final myId = context.read<ProfileCubit>().state.profile?.userId;
    Navigator.of(context).pushNamed(
      userId == myId ? AppRoutes.myProfile : AppRoutes.userProfile,
      arguments: userId,
    );
  }

  Future<void> _run(Future<dynamic> Function() action) async {
    final error = await action();
    if (error != null && mounted) AppFeedback.error(context, error);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Container(
        color: AppColors.backgroundSecondary,
        child: Column(
          children: [
            _SearchEntry(
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.searchUsers),
            ),
            BlocBuilder<FriendsCubit, FriendsState>(
              builder: (context, state) => _SegmentBar(
                selected: _segment,
                requestCount: state.received.length,
                friendCount: state.friends.length,
                onSelected: (s) => setState(() => _segment = s),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: BlocBuilder<FriendsCubit, FriendsState>(
                builder: (context, state) => RefreshIndicator(
                  onRefresh: _cubit.load,
                  child: switch (_segment) {
                    _Segment.suggestions => _suggestions(state),
                    _Segment.requests => _requests(state),
                    _Segment.friends => _friendsList(state),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Gợi ý ----------------
  Widget _suggestions(FriendsState state) {
    if (state.suggestionsStatus == SectionStatus.loading) {
      return const _LoadingList();
    }
    if (state.suggestionsStatus == SectionStatus.failure) {
      return _Message(
        icon: AppIcons.offline,
        title: 'Không tải được gợi ý',
        message: 'Kiểm tra kết nối rồi thử lại.',
        actionLabel: 'Thử lại',
        onAction: _cubit.refreshSuggestions,
      );
    }
    if (state.suggestions.isEmpty) {
      return _Message(
        icon: AppIcons.friends,
        title: 'Chưa có gợi ý nào',
        message: 'Bạn đã kết nối với hầu hết mọi người cùng vai trò.',
        actionLabel: 'Làm mới',
        onAction: _cubit.refreshSuggestions,
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        _SectionHeader(
          title: 'Những người bạn có thể biết',
          trailing: TextButton(
            onPressed: _cubit.refreshSuggestions,
            child: const Text('Làm mới'),
          ),
        ),
        for (final u in state.suggestions) ...[
          PersonCard(
            key: ValueKey('sg_${u.userId}'),
            name: u.fullName,
            subtitle: u.subtitle,
            avatarUrl: u.avatarUrl,
            frameUrl: u.frameUrl,
            onTap: () => _openProfile(u.userId),
            primaryLabel: 'Thêm bạn bè',
            onPrimary: () => _run(() => _cubit.sendRequest(u)),
            secondaryLabel: 'Gỡ',
            onSecondary: () => _cubit.dismissSuggestion(u.userId),
            busy: state.busy.contains(u.userId),
          ),
          const Divider(height: 1, indent: 88),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  // ---------------- Lời mời ----------------
  Widget _requests(FriendsState state) {
    if (state.requestsStatus == SectionStatus.loading) {
      return const _LoadingList();
    }
    if (state.requestsStatus == SectionStatus.failure) {
      return _Message(
        icon: AppIcons.offline,
        title: 'Không tải được lời mời',
        message: 'Kiểm tra kết nối rồi thử lại.',
        actionLabel: 'Thử lại',
        onAction: _cubit.load,
      );
    }
    if (state.received.isEmpty && state.sent.isEmpty) {
      return _Message(
        icon: AppIcons.friends,
        title: 'Không có lời mời nào',
        message: 'Lời mời kết bạn bạn nhận và đã gửi sẽ hiện ở đây.',
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        if (state.received.isNotEmpty) ...[
          _SectionHeader(title: 'Lời mời kết bạn · ${state.received.length}'),
          for (final r in state.received) ...[
            PersonCard(
              key: ValueKey('rq_${r.user.userId}'),
              name: r.user.fullName,
              subtitle: _requestSubtitle(r),
              avatarUrl: r.user.avatarUrl,
              frameUrl: r.user.frameUrl,
              onTap: () => _openProfile(r.user.userId),
              primaryLabel: 'Xác nhận',
              onPrimary: () => _run(() => _cubit.accept(r)),
              secondaryLabel: 'Xoá',
              onSecondary: () => _run(() => _cubit.decline(r)),
              busy: state.busy.contains(r.user.userId),
            ),
            const Divider(height: 1, indent: 88),
          ],
        ],
        if (state.sent.isNotEmpty) ...[
          _SectionHeader(title: 'Đã gửi · ${state.sent.length}'),
          for (final r in state.sent) ...[
            PersonCard(
              key: ValueKey('st_${r.user.userId}'),
              name: r.user.fullName,
              subtitle: _requestSubtitle(r),
              avatarUrl: r.user.avatarUrl,
              frameUrl: r.user.frameUrl,
              onTap: () => _openProfile(r.user.userId),
              statusText: 'Đã gửi lời mời · chờ phản hồi',
            ),
            const Divider(height: 1, indent: 88),
          ],
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  String? _requestSubtitle(FriendRequestModel r) {
    final parts = <String>[
      if (r.mutualFriendsCount > 0) '${r.mutualFriendsCount} bạn chung',
      if (r.createdAt != null) TimeFormat.ago(r.createdAt),
    ].where((e) => e.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' · ');
  }

  // ---------------- Bạn bè ----------------
  Widget _friendsList(FriendsState state) {
    if (state.friendsStatus == SectionStatus.loading) {
      return const _LoadingList();
    }
    if (state.friendsStatus == SectionStatus.failure) {
      return _Message(
        icon: AppIcons.offline,
        title: 'Không tải được danh sách bạn bè',
        message: 'Kiểm tra kết nối rồi thử lại.',
        actionLabel: 'Thử lại',
        onAction: _cubit.load,
      );
    }
    if (state.friends.isEmpty) {
      return _Message(
        icon: AppIcons.friends,
        title: 'Bạn chưa có bạn bè nào',
        message: 'Xem gợi ý hoặc tìm bạn theo tên, mã SV/GV, email.',
        actionLabel: 'Tìm bạn bè',
        onAction: () => Navigator.of(context).pushNamed(AppRoutes.searchUsers),
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        _SectionHeader(title: '${state.friends.length} bạn bè'),
        for (final f in state.friends) ...[
          PersonCard(
            key: ValueKey('fr_${f.userId}'),
            name: f.fullName,
            subtitle: f.mutualFriendsCount > 0
                ? '${f.mutualFriendsCount} bạn chung'
                : null,
            avatarUrl: f.avatarUrl,
            frameUrl: f.frameUrl,
            onTap: () => _openProfile(f.userId),
            trailing: IconButton(
              icon: const Icon(AppIcons.more),
              color: AppColors.textSecondary,
              onPressed: () => _friendMenu(f),
            ),
          ),
          const Divider(height: 1, indent: 88),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _friendMenu(FriendModel f) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.person),
              title: Text('Xem trang cá nhân của ${f.fullName}'),
              onTap: () => Navigator.pop(ctx, 'profile'),
            ),
            ListTile(
              leading: const Icon(AppIcons.logout, color: AppColors.error),
              title: const Text(
                'Hủy kết bạn',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () => Navigator.pop(ctx, 'unfriend'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'profile') {
      _openProfile(f.userId);
    } else if (action == 'unfriend') {
      final ok = await showConfirmDialog(
        context,
        title: 'Hủy kết bạn',
        message: 'Bạn và ${f.fullName} sẽ không còn là bạn bè.',
        confirmLabel: 'Hủy kết bạn',
        destructive: true,
      );
      if (ok) _run(() => _cubit.unfriend(f));
    }
  }
}

/// Ô tìm kiếm giả ở đầu tab (bấm để mở màn tìm kiếm).
class _SearchEntry extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchEntry({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
        onTap: onTap,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
          ),
          child: Row(
            children: [
              const Icon(
                AppIcons.search,
                size: 22,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tìm bạn theo tên, mã SV/GV hoặc email',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 3 nút lựa chọn nhóm (dạng viên thuốc xám, đang chọn tô màu thương hiệu).
class _SegmentBar extends StatelessWidget {
  final _Segment selected;
  final int requestCount;
  final int friendCount;
  final ValueChanged<_Segment> onSelected;

  const _SegmentBar({
    required this.selected,
    required this.requestCount,
    required this.friendCount,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    Widget pill(_Segment s, String label, {int badge = 0}) {
      final on = s == selected;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
          onTap: () => onSelected(s),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: on ? AppColors.primary600 : AppColors.chip,
              borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: on ? AppColors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (badge > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: on ? AppColors.white : AppColors.primary600,
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusFull,
                      ),
                    ),
                    child: Text(
                      '$badge',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: on ? AppColors.primary600 : AppColors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            pill(_Segment.suggestions, 'Gợi ý'),
            pill(_Segment.requests, 'Lời mời', badge: requestCount),
            pill(_Segment.friends, 'Bạn bè'),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) =>
      ListView(children: const [SizedBox(height: 120), LoadingView()]);
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.5,
          child: EmptyView(
            icon: icon,
            title: title,
            message: message,
            action: actionLabel == null
                ? null
                : AppButton(
                    label: actionLabel!,
                    small: true,
                    expand: false,
                    onPressed: onAction,
                  ),
          ),
        ),
      ],
    );
  }
}
