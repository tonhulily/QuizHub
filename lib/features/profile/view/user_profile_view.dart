import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/paged_cubit.dart';
import '../../../core/design_system/component_tokens.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/fb_widgets.dart';
import '../../../core/widgets/paged_list.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/profile_model.dart';
import '../../../data/repositories/post_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../di/locator.dart';
import '../../../shared/post/post_card.dart';
import '../widgets/overlay_button.dart';
import '../widgets/profile_header.dart';
import '../../../core/design_system/app_icons.dart';

/// Trang cá nhân của NGƯỜI KHÁC (`GET /users/{id}` + `GET /users/{id}/posts`).
///
/// Các nút Kết bạn / Theo dõi / Chặn thuộc module Quan hệ - truyền vào
/// [actionsBuilder] khi tích hợp, KHÔNG sửa file này.
class UserProfileView extends StatefulWidget {
  final int userId;
  final Widget Function(BuildContext context, ProfileModel profile)?
  actionsBuilder;

  const UserProfileView({super.key, required this.userId, this.actionsBuilder});

  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<UserProfileView> {
  late final PagedCubit<PostModel> _posts = PagedCubit<PostModel>(
    (after) => getIt<PostRepository>().userPosts(widget.userId, after: after),
  );

  ProfileModel? _profile;
  ApiException? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _posts.close();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await getIt<UserRepository>().getUser(widget.userId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
      _posts.load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final profile = await getIt<UserRepository>().getUser(widget.userId);
      if (mounted) setState(() => _profile = profile);
    } on ApiException {
      // giữ nguyên hồ sơ cũ
    }
    await _posts.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final back = OverlayButton(
      icon: AppIcons.back,
      onTap: () => Navigator.of(context).maybePop(),
    );

    if (_loading) {
      return Scaffold(appBar: AppBar(), body: const LoadingView());
    }
    if (_error != null || _profile == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView(error: _error, onRetry: _loadProfile),
      );
    }

    final profile = _profile!;
    return BlocProvider.value(
      value: _posts,
      child: Scaffold(
        // Dải nền cố định dưới thanh trạng thái: nội dung không cuộn lên safe area
        body: StatusBarSafe(
          child: PagedListView<PostModel>(
            padding: EdgeInsets.zero,
            itemSpacing: ComponentTokens.postGap,
            onRefresh: _refresh,
            header: Column(
              children: [
                ProfileHeader(
                  profile: profile,
                  topLeft: back,
                  actions: widget.actionsBuilder?.call(context, profile),
                ),
              ],
            ),
            emptyView: const EmptyView(
              icon: AppIcons.article,
              title: 'Chưa có bài viết nào',
              compact: true,
            ),
            itemBuilder: (context, post) => PostCard(
              key: ValueKey('post_${post.postId}'),
              post: post,
              onChanged: (p) =>
                  _posts.replaceWhere((x) => x.postId == p.postId, p),
              onDeleted: (p) => _posts.removeWhere((x) => x.postId == p.postId),
            ),
          ),
        ),
      ),
    );
  }
}
