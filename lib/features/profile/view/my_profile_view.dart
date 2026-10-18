import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/paged_cubit.dart';
import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/component_tokens.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/post_events.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/fb_widgets.dart';
import '../../../core/widgets/paged_list.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/post_model.dart';
import '../../../data/repositories/post_repository.dart';
import '../../../di/locator.dart';
import '../../../shared/post/post_card.dart';
import '../../../shared/post/post_composer_bar.dart';
import '../../auth/logout_action.dart';
import '../cubit/profile_cubit.dart';
import '../widgets/overlay_button.dart';
import '../widgets/profile_header.dart';
import '../../../core/design_system/app_icons.dart';

/// Trang cá nhân của CHÍNH MÌNH. Dùng như màn riêng được push
/// (từ Menu hoặc bấm vào tên/avatar của mình).
class MyProfileView extends StatefulWidget {
  final bool showBackButton;

  const MyProfileView({super.key, this.showBackButton = false});

  @override
  State<MyProfileView> createState() => _MyProfileViewState();
}

class _MyProfileViewState extends State<MyProfileView> {
  late final PagedCubit<PostModel> _posts = PagedCubit<PostModel>(
    (after) => getIt<PostRepository>().myPosts(after: after),
  )..load();
  late final StreamSubscription<PostModel> _sub;

  @override
  void initState() {
    super.initState();
    // Bài vừa đăng (từ màn Tạo bài viết) tự chèn lên đầu danh sách
    _sub = getIt<PostEvents>().onPublished.listen(_posts.insertFirst);
  }

  @override
  void dispose() {
    _sub.cancel();
    _posts.close();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<ProfileCubit>().load(silent: true),
      _posts.refresh(),
    ]);
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.edit),
              title: const Text('Chỉnh sửa trang cá nhân'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, AppRoutes.editProfile);
              },
            ),
            ListTile(
              leading: const Icon(AppIcons.passwordReset),
              title: const Text('Đổi mật khẩu'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, AppRoutes.changePassword);
              },
            ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(AppIcons.logout, color: AppColors.error),
              title: const Text(
                'Đăng xuất',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                confirmAndLogout(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _posts,
      child: Scaffold(
        // Dải nền cố định dưới thanh trạng thái: nội dung không cuộn lên safe area
        body: StatusBarSafe(
          child: BlocBuilder<ProfileCubit, ProfileState>(
            builder: (context, state) {
              final profile = state.profile;
              if (profile == null) {
                if (state.status == ProfileStatus.failure) {
                  return ErrorView(
                    error: state.error,
                    onRetry: () => context.read<ProfileCubit>().load(),
                  );
                }
                return const LoadingView();
              }

              final header = ProfileHeader(
                profile: profile,
                topLeft: !widget.showBackButton
                    ? null
                    : OverlayButton(
                        icon: AppIcons.back,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                actions: Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Chỉnh sửa trang cá nhân',
                        icon: AppIcons.edit,
                        small: true,
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.editProfile),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: ComponentTokens.buttonHeightSmall,
                      width: 48,
                      child: FilledButton(
                        onPressed: _openMenu,
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
              );

              return PagedListView<PostModel>(
                padding: EdgeInsets.zero,
                itemSpacing: ComponentTokens.postGap,
                header: Column(
                  children: [
                    header,
                    const SectionGap(),
                    const PostComposerBar(),
                  ],
                ),
                onRefresh: _refresh,
                emptyView: const EmptyView(
                  icon: AppIcons.article,
                  title: 'Bạn chưa có bài viết nào',
                  message: 'Các bài viết bạn đăng sẽ xuất hiện ở đây.',
                  compact: true,
                ),
                itemBuilder: (context, post) => PostCard(
                  key: ValueKey('post_${post.postId}'),
                  post: post,
                  onChanged: (p) =>
                      _posts.replaceWhere((x) => x.postId == p.postId, p),
                  onDeleted: (p) =>
                      _posts.removeWhere((x) => x.postId == p.postId),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
