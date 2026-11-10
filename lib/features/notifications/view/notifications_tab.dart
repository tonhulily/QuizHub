import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/paged_cubit.dart';
import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_icons.dart';
import '../../../core/widgets/fb_widgets.dart';
import '../../../core/widgets/paged_list.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/notification_models.dart';
import '../../../di/locator.dart';
import '../cubit/notification_cubit.dart';
import '../cubit/notification_state.dart';
import '../navigation/notification_navigator.dart';

/// Tab danh sách thông báo của người dùng.
/// Header tiêu đề đã được MainShell đảm nhiệm.
class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NotificationCubit(getIt())..load(),
      child: Builder(
        builder: (context) {
          final notificationCubit = context.read<NotificationCubit>();
          return BlocProvider<PagedCubit<NotificationModel>>.value(
            value: notificationCubit.notificationsCubit,
            child: const _NotificationsBody(),
          );
        },
      ),
    );
  }
}

class _NotificationsBody extends StatelessWidget {
  const _NotificationsBody();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.white,
      child: Column(
        children: [
          BlocBuilder<NotificationCubit, NotificationState>(
            builder: (context, state) => _NotificationActions(
              unreadCount: state.unreadCount,
              isMarkingAll: state.markingAllAsRead,
              onMarkAll: () => _markAll(context),
            ),
          ),
          Expanded(
            child: PagedListView<NotificationModel>(
              padding: EdgeInsets.zero,
              itemSpacing: 0,
              emptyView: const _EmptyNotifications(),
              loadingView: const _NotificationLoading(),
              itemBuilder: (context, item) => _NotificationTile(
                notification: item,
                onTap: () => _openNotification(context, item),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markAll(BuildContext context) async {
    final error = await context.read<NotificationCubit>().markAllAsRead();
    if (!context.mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.message)),
    );
  }

  Future<void> _openNotification(
    BuildContext context,
    NotificationModel item,
  ) async {
    final error = await context.read<NotificationCubit>().markAsRead(item);
    if (!context.mounted) return;

    // Lỗi đánh dấu đã đọc không nên chặn người dùng mở nội dung liên quan.
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }

    await NotificationNavigator.open(context, item);
  }
}

class _NotificationActions extends StatelessWidget {
  final int unreadCount;
  final bool isMarkingAll;
  final VoidCallback onMarkAll;

  const _NotificationActions({
    required this.unreadCount,
    required this.isMarkingAll,
    required this.onMarkAll,
  });

  @override
  Widget build(BuildContext context) {
    return FlatSection(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              unreadCount > 0 ? '$unreadCount thông báo chưa đọc' : 'Tất cả đã đọc',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          TextButton(
            onPressed: unreadCount == 0 || isMarkingAll ? null : onMarkAll,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary600,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: isMarkingAll
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Đánh dấu đã đọc'),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final actor = notification.actor;
    return BlocBuilder<NotificationCubit, NotificationState>(
      buildWhen: (previous, current) =>
          previous.busyNotificationIds != current.busyNotificationIds,
      builder: (context, state) {
        final isBusy = state.busyNotificationIds.contains(
          notification.notificationId,
        );
        return Material(
          color: notification.isRead ? AppColors.white : AppColors.primary50,
          child: InkWell(
            onTap: isBusy ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _NotificationAvatar(notification: notification),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              if (actor != null && actor.fullName.isNotEmpty)
                                TextSpan(
                                  text: '${actor.fullName} ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              TextSpan(text: notification.title),
                            ],
                          ),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textPrimary,
                                height: 1.35,
                              ),
                        ),
                        if (notification.body.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            notification.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.3,
                                ),
                          ),
                        ],
                        const SizedBox(height: 5),
                        Text(
                          _formatNotificationTime(notification.createdAt),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.textTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isBusy)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (!notification.isRead)
                    const Icon(
                      AppIcons.info,
                      size: 10,
                      color: AppColors.primary600,
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

class _NotificationAvatar extends StatelessWidget {
  final NotificationModel notification;

  const _NotificationAvatar({required this.notification});

  @override
  Widget build(BuildContext context) {
    final actor = notification.actor;
    if (actor != null) {
      return UserAvatar(
        avatarUrl: actor.avatarUrl,
        frameUrl: actor.frameUrl,
        name: actor.fullName,
        size: 48,
      );
    }

    final imageUrl = notification.iconUrl;
    return SizedBox(
      width: 48,
      height: 48,
      child: ClipOval(
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallbackIcon(),
              )
            : _fallbackIcon(),
      ),
    );
  }

  Widget _fallbackIcon() => const ColoredBox(
        color: AppColors.primary100,
        child: Icon(AppIcons.notificationsActive, color: AppColors.primary600),
      );
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.inbox, size: 52, color: AppColors.textTertiary),
            SizedBox(height: 12),
            Text(
              'Chưa có thông báo',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Các hoạt động mới liên quan đến tài khoản của bạn sẽ xuất hiện ở đây.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationLoading extends StatelessWidget {
  const _NotificationLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: CircularProgressIndicator(color: AppColors.primary600),
      ),
    );
  }
}

String _formatNotificationTime(DateTime? value) {
  if (value == null) return '';
  final now = DateTime.now();
  final time = value.toLocal();
  final difference = now.difference(time);
  if (difference.inMinutes < 1) return 'Vừa xong';
  if (difference.inHours < 1) return '${difference.inMinutes} phút trước';
  if (difference.inDays < 1) return '${difference.inHours} giờ trước';
  if (difference.inDays == 1) return 'Hôm qua';
  if (time.year == now.year) return '${time.day}/${time.month}';
  return '${time.day}/${time.month}/${time.year}';
}
