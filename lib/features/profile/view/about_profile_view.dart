import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/design_system/design_tokens.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/profile_model.dart';
import '../cubit/profile_cubit.dart';
import '../widgets/info_grid.dart';

/// Các mục thông tin của một hồ sơ (dùng cho trang Giới thiệu).
List<InfoItem> profileInfoItems(ProfileModel p) {
  bool has(String? v) => (v ?? '').trim().isNotEmpty;
  return [
    if (has(p.studentLecturerCode))
      InfoItem(
        icon: AppIcons.idCard,
        label: 'Mã SV/GV',
        value: p.studentLecturerCode!,
        color: AppColors.info,
      ),
    if (has(p.schoolFaculty))
      InfoItem(
        icon: AppIcons.faculty,
        label: 'Khoa / Viện',
        value: p.schoolFaculty!,
        color: AppColors.primary600,
      ),
    if (has(p.major))
      InfoItem(
        icon: AppIcons.school,
        label: 'Chuyên ngành',
        value: p.major!,
        color: AppColors.secondary600,
      ),
    if (has(p.className))
      InfoItem(
        icon: AppIcons.classGroup,
        label: 'Lớp',
        value: p.className!,
        color: AppColors.success,
      ),
    if (p.gender != null)
      InfoItem(
        icon: p.gender == Gender.male
            ? AppIcons.genderMale
            : AppIcons.genderFemale,
        label: 'Giới tính',
        value: p.gender!.label,
        color: AppColors.primary500,
      ),
    // Server chỉ trả ngày sinh khi xem hồ sơ của chính mình
    if (p.dateOfBirth != null)
      InfoItem(
        icon: AppIcons.birthday,
        label: 'Ngày sinh',
        value: TimeFormat.date(p.dateOfBirth),
        color: AppColors.warningDark,
        audience: InfoAudience.onlyMe,
      ),
    if (p.createdAt != null)
      InfoItem(
        icon: AppIcons.joined,
        label: 'Tham gia từ',
        value: TimeFormat.date(p.createdAt),
        color: AppColors.neutral500,
      ),
  ];
}

/// Trang "Giới thiệu" đầy đủ (mở bằng nút "Xem thông tin giới thiệu" ở trang
/// cá nhân).
///
/// Bố cục: phần đầu gọn (avatar viền gradient + tên + vai trò + tiểu sử),
/// lưới thống kê dạng bento, dải kết nối, rồi các danh sách thông tin gom nhóm.
/// Với hồ sơ của chính mình, dữ liệu luôn lấy mới nhất từ [ProfileCubit].
class AboutProfileView extends StatelessWidget {
  final ProfileModel profile;

  const AboutProfileView({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProfileCubit>();
    final isMe = cubit.state.profile?.userId == profile.userId;
    if (!isMe) return _AboutBody(profile: profile, isMe: false);
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) =>
          _AboutBody(profile: state.profile ?? profile, isMe: true),
    );
  }
}

class _AboutBody extends StatelessWidget {
  final ProfileModel profile;
  final bool isMe;

  const _AboutBody({required this.profile, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final points = p.gamificationPoints % 1 == 0
        ? p.gamificationPoints.toInt().toString()
        : p.gamificationPoints.toStringAsFixed(1);
    final info = profileInfoItems(p);

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(title: const Text('Giới thiệu')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
        children: [
          _Identity(profile: p),
          const SizedBox(height: 18),
          _StatsBento(
            points: points,
            questions: p.totalProposedQuestions,
            badges: p.badgesCount,
          ),
          const SizedBox(height: 12),
          _ConnectionsStrip(
            friends: p.friendsCount,
            followers: p.followersCount,
            following: p.followingCount,
          ),
          if (info.isNotEmpty) ...[
            const _GroupLabel('Thông tin cá nhân'),
            _InfoList(items: info),
          ],
          if (isMe && (p.email ?? '').isNotEmpty) ...[
            const _GroupLabel('Tài khoản'),
            _InfoList(
              items: [
                InfoItem(
                  icon: AppIcons.emailAddress,
                  label: 'Email',
                  value: p.email!,
                  color: AppColors.warningDark,
                  audience: InfoAudience.onlyMe,
                ),
              ],
            ),
          ],
          if (isMe) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    AppIcons.audienceOnlyMe,
                    size: 15,
                    color: AppColors.warningDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ngày sinh và email chỉ mình bạn nhìn thấy; người khác '
                    'không xem được.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Chỉnh sửa hồ sơ',
              icon: AppIcons.edit,
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.editProfile),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Phần đầu: không khung, nằm thẳng trên nền trang
// ---------------------------------------------------------------------------

class _Identity extends StatelessWidget {
  final ProfileModel profile;
  const _Identity({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = profile;
    final lecturer = p.role.isLecturer;
    final bio = (p.bio ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Viền gradient thương hiệu quanh avatar
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.brandGradient,
              ),
              child: UserAvatar(
                avatarUrl: p.avatarUrl,
                frameUrl: p.frameUrl,
                name: p.fullName,
                size: 76,
                showBorder: true,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.fullName.isEmpty ? 'Chưa đặt tên' : p.fullName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: lecturer
                          ? AppColors.secondary100
                          : AppColors.primary100,
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusFull,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          lecturer ? AppIcons.lecturer : AppIcons.schoolFill,
                          size: 15,
                          color: lecturer
                              ? AppColors.secondary700
                              : AppColors.primary700,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          p.role.label,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: lecturer
                                ? AppColors.secondary800
                                : AppColors.primary800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            bio,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Thống kê dạng bento: 1 ô lớn (điểm) + 2 ô nhỏ xếp dọc, biểu tượng mờ làm nền
// ---------------------------------------------------------------------------

class _StatsBento extends StatelessWidget {
  final String points;
  final int questions;
  final int badges;

  const _StatsBento({
    required this.points,
    required this.questions,
    required this.badges,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 178,
      child: Row(
        children: [
          Expanded(
            flex: 11,
            child: _BentoTile(
              icon: AppIcons.points,
              color: AppColors.secondary600,
              value: points,
              label: 'Điểm tích luỹ',
              big: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 9,
            child: Column(
              children: [
                Expanded(
                  child: _BentoTile(
                    icon: AppIcons.quizActive,
                    watermark: AppIcons.questionMark,
                    color: AppColors.primary600,
                    value: '$questions',
                    label: 'Câu hỏi',
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _BentoTile(
                    icon: AppIcons.badge,
                    color: AppColors.info,
                    value: '$badges',
                    label: 'Huy hiệu',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BentoTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final bool big;

  /// Biểu tượng mờ làm nền (mặc định dùng chính [icon]).
  final IconData? watermark;

  const _BentoTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.big = false,
    this.watermark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0.07),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Biểu tượng khổng lồ, mờ, nhô ra khỏi góc
            Positioned(
              right: big ? -18 : -10,
              bottom: big ? -22 : -14,
              child: Icon(
                watermark ?? icon,
                size: big ? 130 : 78,
                color: color.withValues(alpha: 0.16),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 20, color: color),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (big
                                ? theme.textTheme.displaySmall
                                : theme.textTheme.headlineMedium)
                            ?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dải kết nối: một thanh duy nhất, 3 cột
// ---------------------------------------------------------------------------

class _ConnectionsStrip extends StatelessWidget {
  final int friends;
  final int followers;
  final int following;

  const _ConnectionsStrip({
    required this.friends,
    required this.followers,
    required this.following,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _Connection(value: friends, label: 'Bạn bè', color: AppColors.info),
            const VerticalDivider(width: 1, thickness: 1),
            _Connection(
              value: followers,
              label: 'Người theo dõi',
              color: AppColors.primary600,
            ),
            const VerticalDivider(width: 1, thickness: 1),
            _Connection(
              value: following,
              label: 'Đang theo dõi',
              color: AppColors.success,
            ),
          ],
        ),
      ),
    );
  }
}

class _Connection extends StatelessWidget {
  final int value;
  final String label;
  final Color color;

  const _Connection({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            TimeFormat.compact(value),
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Danh sách thông tin gom nhóm (một khối bo tròn, hàng cách nhau bằng kẻ mảnh)
// ---------------------------------------------------------------------------

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 22, 6, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _InfoList extends StatelessWidget {
  final List<InfoItem> items;
  const _InfoList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 66),
            _InfoRowTile(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _InfoRowTile extends StatelessWidget {
  final InfoItem item;
  const _InfoRowTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onlyMe = item.audience == InfoAudience.onlyMe;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(item.icon, size: 22, color: item.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: theme.textTheme.bodySmall),
                const SizedBox(height: 1),
                Text(
                  item.value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (onlyMe) ...[
            const SizedBox(width: 8),
            const Tooltip(
              message: 'Chỉ mình bạn thấy',
              child: Icon(
                AppIcons.audienceOnlyMe,
                size: 18,
                color: AppColors.warningDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
