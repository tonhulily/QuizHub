import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/fb_widgets.dart';
import '../../core/widgets/user_avatar.dart';
import '../../features/profile/cubit/profile_cubit.dart';
import '../../core/design_system/app_icons.dart';

/// Thanh "Bạn đang nghĩ gì?" ở đầu Bảng tin / Trang cá nhân của mình.
/// Bấm vào để mở màn Tạo bài viết (bài đăng xong sẽ tự chèn vào danh sách
/// qua `PostEvents`).
class PostComposerBar extends StatelessWidget {
  const PostComposerBar({super.key});

  void _open(BuildContext context, {bool pickImages = false}) {
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.createPost, arguments: pickImages);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FlatSection(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          BlocBuilder<ProfileCubit, ProfileState>(
            buildWhen: (a, b) => a.profile != b.profile,
            builder: (context, state) => UserAvatar(
              avatarUrl: state.profile?.avatarUrl,
              frameUrl: state.profile?.frameUrl,
              name: state.profile?.fullName ?? '',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => _open(context),
              child: Container(
                height: 40,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Bạn đang nghĩ gì?',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Ảnh',
            iconSize: 30,
            icon: const Icon(AppIcons.photosFill, color: AppColors.success),
            onPressed: () => _open(context, pickImages: true),
          ),
        ],
      ),
    );
  }
}
