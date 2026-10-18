import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/design_system/component_tokens.dart';
import '../../../core/services/social_events.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/repositories/friend_repository.dart';
import '../../../data/repositories/report_repository.dart';
import '../../../di/locator.dart';
import '../../../shared/report/report_sheet.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/user_relation_cubit.dart';

/// Hàng nút trên trang cá nhân của NGƯỜI KHÁC, kiểu Facebook:
/// Thêm bạn bè / Đã gửi lời mời / Xác nhận - Xoá / Bạn bè ▾, kèm Theo dõi và ⋯.
///
/// Truyền vào `UserProfileView.actionsBuilder`:
/// `actionsBuilder: (context, profile) => FriendActions(profile: profile)`.
class FriendActions extends StatelessWidget {
  final ProfileModel profile;

  const FriendActions({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UserRelationCubit(
        getIt<FriendRepository>(),
        getIt<SocialEvents>(),
        userId: profile.userId,
        initial: profile.relationships ?? const RelationshipModel(),
      ),
      child: _Body(profile: profile),
    );
  }
}

class _Body extends StatelessWidget {
  final ProfileModel profile;
  const _Body({required this.profile});

  Future<void> _run(
    BuildContext context,
    Future<dynamic> Function() action, {
    String? success,
  }) async {
    final error = await action();
    if (!context.mounted) return;
    if (error != null) {
      AppFeedback.error(context, error);
    } else if (success != null) {
      AppFeedback.success(context, success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<UserRelationCubit>();
    final myRole = context.read<ProfileCubit>().state.profile?.role;
    // Backend chỉ cho kết bạn giữa người CÙNG vai trò
    final canFriend = myRole == null || myRole == profile.role;

    return BlocBuilder<UserRelationCubit, UserRelationState>(
      builder: (context, state) {
        final rel = state.relationship;
        final busy = state.busy;

        // ---- Nút chính theo trạng thái ----
        final List<Widget> main;
        if (state.isFriend) {
          main = [
            Expanded(
              child: AppButton(
                label: 'Bạn bè',
                icon: AppIcons.friendsActive,
                small: true,
                variant: AppButtonVariant.neutral,
                onPressed: busy ? null : () => _friendMenu(context, cubit),
              ),
            ),
          ];
        } else if (state.isPending && state.incoming == true) {
          main = [
            Expanded(
              child: AppButton(
                label: 'Xác nhận',
                small: true,
                onPressed: busy
                    ? null
                    : () => _run(
                        context,
                        cubit.accept,
                        success: 'Đã trở thành bạn bè',
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                label: 'Xoá',
                small: true,
                variant: AppButtonVariant.neutral,
                onPressed: busy ? null : () => _run(context, cubit.decline),
              ),
            ),
          ];
        } else if (state.isPending) {
          main = [
            const Expanded(
              child: AppButton(
                label: 'Đã gửi lời mời',
                icon: AppIcons.joined,
                small: true,
                variant: AppButtonVariant.neutral,
              ),
            ),
          ];
        } else if (canFriend) {
          main = [
            Expanded(
              child: AppButton(
                label: 'Thêm bạn bè',
                icon: AppIcons.add,
                small: true,
                onPressed: busy
                    ? null
                    : () => _run(
                        context,
                        cubit.addFriend,
                        success: 'Đã gửi lời mời kết bạn',
                      ),
              ),
            ),
          ];
        } else {
          main = const [];
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ...main,
                if (main.isNotEmpty) const SizedBox(width: 8),
                // Theo dõi (không phân biệt vai trò)
                Expanded(
                  child: AppButton(
                    label: rel.isFollowing ? 'Đang theo dõi' : 'Theo dõi',
                    small: true,
                    variant: rel.isFollowing
                        ? AppButtonVariant.neutral
                        : AppButtonVariant.secondary,
                    onPressed: busy
                        ? null
                        : () => _run(context, cubit.toggleFollow),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: ComponentTokens.buttonHeightSmall,
                  width: 48,
                  child: FilledButton(
                    onPressed: () => _moreMenu(context, cubit),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: AppColors.chip,
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          ComponentTokens.buttonRadius,
                        ),
                      ),
                    ),
                    child: const Icon(AppIcons.more),
                  ),
                ),
              ],
            ),
            if (!canFriend && !state.isFriend)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Chỉ kết bạn được với người cùng vai trò '
                  '(sinh viên với sinh viên, giảng viên với giảng viên). '
                  'Bạn vẫn có thể theo dõi.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _friendMenu(
    BuildContext context,
    UserRelationCubit cubit,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
    if (!context.mounted || action != 'unfriend') return;
    final ok = await showConfirmDialog(
      context,
      title: 'Hủy kết bạn',
      message: 'Bạn và ${profile.fullName} sẽ không còn là bạn bè.',
      confirmLabel: 'Hủy kết bạn',
      destructive: true,
    );
    if (ok && context.mounted) {
      await _run(context, cubit.unfriend, success: 'Đã hủy kết bạn');
    }
  }

  Future<void> _moreMenu(BuildContext context, UserRelationCubit cubit) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.flag),
              title: const Text('Báo cáo tài khoản'),
              onTap: () => Navigator.pop(ctx, 'report'),
            ),
            ListTile(
              leading: const Icon(AppIcons.lock, color: AppColors.error),
              title: const Text(
                'Chặn',
                style: TextStyle(color: AppColors.error),
              ),
              subtitle: const Text(
                'Hủy bạn bè và theo dõi hai chiều, không xem bài của nhau.',
              ),
              onTap: () => Navigator.pop(ctx, 'block'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == 'report') {
      await showReportSheet(
        context,
        target: ReportTarget.user,
        targetId: profile.userId,
      );
    } else if (action == 'block') {
      final ok = await showConfirmDialog(
        context,
        title: 'Chặn ${profile.fullName}?',
        message:
            'Hai bên sẽ không còn là bạn bè hoặc theo dõi nhau và không xem '
            'được bài viết của nhau. Bạn có thể bỏ chặn sau.',
        confirmLabel: 'Chặn',
        destructive: true,
      );
      if (!ok || !context.mounted) return;
      final error = await cubit.block();
      if (!context.mounted) return;
      if (error != null) {
        AppFeedback.error(context, error);
      } else {
        AppFeedback.success(context, 'Đã chặn ${profile.fullName}');
        Navigator.of(context).maybePop();
      }
    }
  }
}
