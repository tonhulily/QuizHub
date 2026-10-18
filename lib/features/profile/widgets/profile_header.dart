import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/component_tokens.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/fb_widgets.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/auth_session.dart';
import '../../../data/models/media_item.dart';
import '../../../data/models/profile_model.dart';
import '../../../shared/media/media_viewer.dart';
import '../../../core/design_system/app_icons.dart';

/// Phần đầu trang cá nhân kiểu Facebook: ảnh bìa, avatar đè lên bìa (lệch
/// trái), tên, tiểu sử, số bạn bè, nút hành động, danh sách thông tin.
/// Dùng cho cả trang của mình và của người khác.
class ProfileHeader extends StatelessWidget {
  final ProfileModel profile;

  /// Hàng nút dưới tên (Chỉnh sửa / Kết bạn / Theo dõi...)
  final Widget? actions;

  /// Nút nổi góc trên (Back / Menu)
  final Widget? topLeft;
  final Widget? topRight;

  const ProfileHeader({
    super.key,
    required this.profile,
    this.actions,
    this.topLeft,
    this.topRight,
  });

  static const double _coverHeight = 200;
  static const double _avatarSize = ComponentTokens.avatarProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = profile;
    final points = p.gamificationPoints % 1 == 0
        ? p.gamificationPoints.toInt().toString()
        : p.gamificationPoints.toStringAsFixed(1);

    return FlatSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Cover + avatar ----
          SizedBox(
            height: _coverHeight + _avatarSize / 2,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _coverHeight,
                  child: GestureDetector(
                    onTap: (p.coverUrl ?? '').isEmpty
                        ? null
                        : () => MediaViewer.open(context, [
                            MediaItem(url: p.coverUrl!),
                          ]),
                    child: _Cover(url: p.coverUrl),
                  ),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 8,
                  left: 12,
                  child: topLeft ?? const SizedBox.shrink(),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 8,
                  right: 12,
                  child: topRight ?? const SizedBox.shrink(),
                ),
                Positioned(
                  bottom: 0,
                  left: 12,
                  child: UserAvatar(
                    avatarUrl: p.avatarUrl,
                    frameUrl: p.frameUrl,
                    name: p.fullName,
                    size: _avatarSize,
                    showBorder: true,
                    onTap: (p.avatarUrl ?? '').isEmpty
                        ? null
                        : () => MediaViewer.open(context, [
                            MediaItem(url: p.avatarUrl!),
                          ]),
                  ),
                ),
              ],
            ),
          ),
          // ---- Tên / vai trò / tiểu sử ----
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.fullName.isEmpty ? 'Chưa đặt tên' : p.fullName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                _RoleChip(role: p.role),
                if ((p.bio ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    p.bio!,
                    style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15),
                  ),
                ],
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      _count(p.friendsCount, 'bạn bè'),
                      const TextSpan(text: '  ·  '),
                      _count(p.followersCount, 'người theo dõi'),
                      const TextSpan(text: '  ·  '),
                      _count(p.followingCount, 'đang theo dõi'),
                    ],
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (actions != null) ...[const SizedBox(height: 12), actions!],
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 14, 12, 0),
            child: Divider(height: 1),
          ),
          // ---- Chi tiết: vài dòng icon + chữ, không khung (như Facebook) ----
          // Thông tin đầy đủ nằm ở trang "Giới thiệu" để bài viết hiện sớm.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chi tiết',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                if (_has(p.schoolFaculty))
                  _DetailLine(
                    icon: AppIcons.faculty,
                    label: 'Học tại ',
                    value: p.schoolFaculty!,
                  ),
                if (_has(p.major))
                  _DetailLine(
                    icon: AppIcons.school,
                    label: 'Chuyên ngành ',
                    value: p.major!,
                  ),
                if (_has(p.studentLecturerCode))
                  _DetailLine(
                    icon: AppIcons.idCard,
                    label: 'Mã SV/GV ',
                    value: p.studentLecturerCode!,
                  ),
                _StatsLine(
                  points: points,
                  questions: p.totalProposedQuestions,
                  badges: p.badgesCount,
                ),
                if (p.createdAt != null)
                  _DetailLine(
                    icon: AppIcons.joined,
                    label: 'Tham gia ',
                    value: TimeFormat.date(p.createdAt),
                  ),
                const SizedBox(height: 10),
                AppButton(
                  label: 'Xem thông tin giới thiệu',
                  small: true,
                  variant: AppButtonVariant.neutral,
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.profileAbout, arguments: p),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static bool _has(String? v) => (v ?? '').trim().isNotEmpty;

  static TextSpan _count(int value, String label) => TextSpan(
    children: [
      TextSpan(
        text: TimeFormat.compact(value),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      TextSpan(text: ' $label'),
    ],
  );
}

class _Cover extends StatelessWidget {
  final String? url;
  const _Cover({this.url});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            left: 30,
            bottom: 40,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary300.withValues(alpha: 0.25),
              ),
            ),
          ),
        ],
      ),
    );
    if ((url ?? '').isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }
}

class _RoleChip extends StatelessWidget {
  final UserRole role;
  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final lecturer = role.isLecturer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: lecturer ? AppColors.secondary100 : AppColors.primary50,
        borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            lecturer ? AppIcons.lecturer : AppIcons.schoolFill,
            size: 16,
            color: lecturer ? AppColors.secondary700 : AppColors.primary700,
          ),
          const SizedBox(width: 5),
          Text(
            role.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: lecturer ? AppColors.secondary800 : AppColors.primary800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Một dòng "icon + nhãn + giá trị đậm", không khung.
class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: label),
                    TextSpan(
                      text: value,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Điểm / câu hỏi / huy hiệu trên một dòng, icon màu, không khung.
class _StatsLine extends StatelessWidget {
  final String points;
  final int questions;
  final int badges;

  const _StatsLine({
    required this.points,
    required this.questions,
    required this.badges,
  });

  @override
  Widget build(BuildContext context) {
    Widget stat(IconData icon, Color color, String value, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' $label'),
              ],
            ),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontSize: 15),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        spacing: 18,
        runSpacing: 6,
        children: [
          stat(AppIcons.points, AppColors.secondary600, points, 'điểm'),
          stat(
            AppIcons.quizActive,
            AppColors.primary600,
            '$questions',
            'câu hỏi',
          ),
          stat(AppIcons.badge, AppColors.info, '$badges', 'huy hiệu'),
        ],
      ),
    );
  }
}
