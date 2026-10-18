import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/bloc/paged_cubit.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/component_tokens.dart';
import '../../core/services/post_events.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/paged_list.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/feed_item.dart';
import '../../data/repositories/feed_repository.dart';
import '../../di/locator.dart';
import '../../shared/post/post_card.dart';
import '../../shared/post/post_composer_bar.dart';
import '../../core/design_system/app_icons.dart';

/// Tab Trang chủ (Bảng tin) kiểu Facebook: thanh "Bạn đang nghĩ gì?" rồi tới
/// danh sách bài viết / hoạt động, ngăn cách bằng dải xám.
///
/// Trang đầu được cache cục bộ nên lần mở sau hiển thị tức thì. Bài vừa đăng
/// (qua [PostEvents]) được chèn lên đầu mà không cần tải lại.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late final PagedCubit<FeedItem> _feed;
  StreamSubscription<dynamic>? _sub;

  @override
  void initState() {
    super.initState();
    final repo = getIt<FeedRepository>();
    _feed = PagedCubit<FeedItem>(
      (after) => repo.getFeed(after: after),
      initialItems: repo.cachedFirstPage?.items,
    )..load();
    _sub = getIt<PostEvents>().onPublished.listen(
      (post) => _feed.insertFirst(FeedItem.fromPost(post)),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _feed.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _feed,
      child: PagedListView<FeedItem>(
        padding: EdgeInsets.zero,
        itemSpacing: ComponentTokens.postGap,
        header: const PostComposerBar(),
        emptyView: const EmptyView(
          icon: AppIcons.feed,
          title: 'Chưa có hoạt động nào',
          message: 'Kết bạn và theo dõi giảng viên để xem bài viết mới ở đây.',
          compact: true,
        ),
        itemBuilder: (context, item) {
          final post = item.toPost();
          if (post != null) {
            return PostCard(
              key: ValueKey('feed_${item.feedId}'),
              post: post,
              onDeleted: (p) => _feed.removeWhere(
                (x) =>
                    x.targetType == item.targetType && x.targetId == p.postId,
              ),
            );
          }
          return _ActivityTile(item: item);
        },
      ),
    );
  }
}

/// Hoạt động không phải bài viết (huy hiệu, câu hỏi được duyệt, mốc...).
/// Trình bày như một dòng thông báo của Facebook.
class _ActivityTile extends StatelessWidget {
  final FeedItem item;
  const _ActivityTile({required this.item});

  (IconData, Color, String) get _meta => switch (item.actionType) {
    'EARNED_BADGE' => (
      AppIcons.badge,
      AppColors.secondary600,
      'đã nhận một huy hiệu mới',
    ),
    'SESSION_RESOLVED_APPROVED' => (
      AppIcons.success,
      AppColors.success,
      'có câu hỏi được giảng viên duyệt',
    ),
    'REACHED_MILESTONE' => (
      AppIcons.trophy,
      AppColors.primary600,
      'đạt một cột mốc mới',
    ),
    'PUBLISHED_LECTURE_VIDEO' => (
      AppIcons.playCircle,
      AppColors.info,
      'đăng video bài giảng mới',
    ),
    _ => (AppIcons.bolt, AppColors.primary600, 'có hoạt động mới'),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, text) = _meta;
    final actor = item.actor;

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: actor?.fullName ?? 'Ai đó',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: ' $text'),
                    ],
                  ),
                  style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  TimeFormat.ago(item.createdAt),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
