import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../design_system/app_colors.dart';
import '../network/api_exception.dart';
import '../utils/error_text.dart';
import 'app_button.dart';
import '../design_system/app_icons.dart';

/// Trạng thái đang tải toàn vùng.
class LoadingView extends StatelessWidget {
  final String? message;

  const LoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// Trạng thái lỗi + nút thử lại. Tự chọn icon/nội dung theo loại lỗi.
class ErrorView extends StatelessWidget {
  final Object? error;
  final String? message;
  final VoidCallback? onRetry;
  final bool compact;

  const ErrorView({
    super.key,
    this.error,
    this.message,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final network = isNetworkError(error);
    final text =
        message ??
        (network
            ? 'Lỗi kết nối. Vui lòng kiểm tra mạng và thử lại.'
            : errorText(error));
    final forbidden =
        error is ApiException &&
        (error as ApiException).type == ApiErrorType.forbidden;

    return _StateLayout(
      icon: network
          ? AppIcons.offline
          : forbidden
          ? AppIcons.lock
          : AppIcons.errorOutline,
      iconColor: network ? AppColors.warning : AppColors.error,
      iconBackground: network ? AppColors.warningLight : AppColors.errorLight,
      title: network ? 'Mất kết nối' : 'Đã có lỗi xảy ra',
      message: text,
      compact: compact,
      action: onRetry == null
          ? null
          : AppButton(
              label: 'Thử lại',
              icon: AppIcons.refresh,
              onPressed: onRetry,
              expand: false,
              small: true,
            ),
    );
  }
}

/// Trạng thái không có dữ liệu.
class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool compact;

  const EmptyView({
    super.key,
    this.icon = AppIcons.inbox,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => _StateLayout(
    icon: icon,
    iconColor: AppColors.primary500,
    iconBackground: AppColors.primary50,
    title: title,
    message: message,
    action: action,
    compact: compact,
  );
}

class _StateLayout extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String? message;
  final Widget? action;
  final bool compact;

  const _StateLayout({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconSize = compact ? 32.0 : 42.0;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(compact ? 14 : 20),
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: iconSize, color: iconColor),
            ),
            SizedBox(height: compact ? 12 : 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (action != null) ...[
              SizedBox(height: compact ? 12 : 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Khung xương shimmer cho danh sách bài viết khi đang tải lần đầu.
class PostListSkeleton extends StatelessWidget {
  final int count;

  const PostListSkeleton({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, _) => const _PostSkeleton(),
      ),
    );
  }
}

class _PostSkeleton extends StatelessWidget {
  const _PostSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(120, 12),
                  const SizedBox(height: 8),
                  bar(70, 10),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          bar(double.infinity, 12),
          const SizedBox(height: 8),
          bar(double.infinity, 12),
          const SizedBox(height: 8),
          bar(180, 12),
          const SizedBox(height: 16),
          bar(double.infinity, 160),
        ],
      ),
    );
  }
}
