import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/fb_widgets.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/auth_session.dart';
import '../auth/logout_action.dart';
import '../shell/main_shell.dart';
import '../profile/cubit/profile_cubit.dart';
import '../../core/design_system/app_icons.dart';

/// Lối tắt hiển thị trong lưới của tab Menu.
///
/// Module nào xong thì thay `onTap` bằng điều hướng thật; mặc định báo
/// "đang phát triển". Thêm / bớt lối tắt chỉ cần sửa [MenuTab.shortcuts].
class MenuShortcut {
  final IconData icon;
  final Color color;
  final String label;
  final void Function(BuildContext context)? onTap;

  const MenuShortcut({
    required this.icon,
    required this.color,
    required this.label,
    this.onTap,
  });
}

/// Tab Menu (giống tab "Menu" của Facebook): thẻ hồ sơ, lối tắt, cài đặt,
/// đăng xuất.
class MenuTab extends StatelessWidget {
  const MenuTab({super.key});

  static void _goToFriends(BuildContext context) =>
      context.findAncestorStateOfType<MainShellState>()?.select(1);

  static void _goToQuestionBank(BuildContext context) =>
      context.findAncestorStateOfType<MainShellState>()?.select(2);

  /// Đề thi chỉ dành cho giảng viên (sinh viên gọi API bị 403).
  static void _openExams(BuildContext context) {
    final role = context.read<ProfileCubit>().state.profile?.role;
    if (role == UserRole.lecturer) {
      Navigator.of(context).pushNamed(AppRoutes.examMyExams);
    } else {
      AppFeedback.info(context, 'Chỉ giảng viên mới sinh và quản lý đề thi.');
    }
  }

  static const List<MenuShortcut> shortcuts = [
    MenuShortcut(
      icon: AppIcons.friendsActive,
      color: AppColors.info,
      label: 'Bạn bè',
      onTap: _goToFriends,
    ),
    MenuShortcut(
      icon: AppIcons.quizActive,
      color: AppColors.primary600,
      label: 'Ngân hàng đề',
      onTap: _goToQuestionBank,
    ),
    MenuShortcut(
      icon: AppIcons.leaderboard,
      color: AppColors.secondary600,
      label: 'Bảng xếp hạng',
    ),
    MenuShortcut(
      icon: AppIcons.badge,
      color: AppColors.success,
      label: 'Huy hiệu',
    ),
    MenuShortcut(
      icon: AppIcons.exam,
      color: AppColors.infoDark,
      label: 'Đề thi của tôi',
      onTap: _openExams,
    ),
    MenuShortcut(
      icon: AppIcons.shop,
      color: AppColors.warningDark,
      label: 'Cửa hàng',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const _ProfileCard(),
        const SectionGap(),
        FlatSection(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lối tắt của bạn',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _ShortcutGrid(items: shortcuts),
            ],
          ),
        ),
        const SectionGap(),
        FlatSection(
          child: Theme(
            // Bỏ đường kẻ mặc định của ExpansionTile
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: const Icon(AppIcons.settings),
              title: Text(
                'Cài đặt & quyền riêng tư',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              children: [
                ListTile(
                  leading: const Icon(AppIcons.edit),
                  title: const Text('Chỉnh sửa trang cá nhân'),
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.editProfile),
                ),
                ListTile(
                  leading: const Icon(AppIcons.passwordReset),
                  title: const Text('Đổi mật khẩu'),
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.changePassword),
                ),
              ],
            ),
          ),
        ),
        const SectionGap(),
        FlatSection(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 40,
            child: FilledButton(
              onPressed: () => confirmAndLogout(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.chip,
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Đăng xuất'),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final p = state.profile;
        final name = (p?.fullName ?? '').trim();
        return Material(
          color: AppColors.white,
          child: InkWell(
            onTap: () => Navigator.pushNamed(context, AppRoutes.myProfile),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  UserAvatar(
                    avatarUrl: p?.avatarUrl,
                    frameUrl: p?.frameUrl,
                    name: name,
                    size: 48,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'Trang cá nhân' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Xem trang cá nhân',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    AppIcons.chevronRight,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShortcutGrid extends StatelessWidget {
  final List<MenuShortcut> items;
  const _ShortcutGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 10.0;
        final width = (c.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final s in items)
              SizedBox(
                width: width,
                child: _ShortcutCard(item: s),
              ),
          ],
        );
      },
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  final MenuShortcut item;
  const _ShortcutCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        onTap: () => item.onTap != null
            ? item.onTap!(context)
            : showComingSoon(context, item.label),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, size: 32, color: item.color),
              const SizedBox(height: 22),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
