import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design_system/app_colors.dart';
import '../design_system/component_tokens.dart';
import 'app_feedback.dart';

/// Nút tròn nền xám nhạt (Tìm kiếm, Nhắn tin, Thêm...) như trên header Facebook.
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color background;
  final Color? color;
  final String? tooltip;

  const CircleIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = ComponentTokens.circleButton,
    this.iconSize = 20,
    this.background = AppColors.chip,
    this.color,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: iconSize,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Icon trần (không nền) trên header - Thêm / Tìm kiếm / Nhắn tin.
/// Vùng bấm 44x44 dù icon chỉ [iconSize].
class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double iconSize;
  final String? tooltip;

  const HeaderIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.iconSize = 30,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    tooltip: tooltip,
    iconSize: iconSize,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    icon: Icon(icon, color: AppColors.textPrimary),
  );
}

/// Dải phân cách xám dày giữa các khối (bài viết, composer, section).
class SectionGap extends StatelessWidget {
  final double height;
  const SectionGap({super.key, this.height = ComponentTokens.postGap});

  @override
  Widget build(BuildContext context) =>
      Container(height: height, color: AppColors.backgroundSecondary);
}

/// Khối nền trắng toàn chiều ngang (không bo góc, không đổ bóng).
class FlatSection extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const FlatSection({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: AppColors.white,
    padding: padding,
    child: child,
  );
}

/// Báo cho người dùng biết tính năng chưa được xây dựng.
/// Dùng cho các nút đã có sẵn giao diện nhưng module tương ứng chưa làm.
void showComingSoon(BuildContext context, [String? feature]) =>
    AppFeedback.info(
      context,
      feature == null
          ? 'Tính năng đang được phát triển.'
          : '$feature đang được phát triển.',
    );

/// Chặn nội dung cuộn lên vùng thanh trạng thái (safe area phía trên).
///
/// Với màn hình cuộn cả trang (vd Trang cá nhân) không có AppBar, chữ sẽ chạy
/// lên dưới giờ/pin của điện thoại. Widget này đặt một dải nền cố định cao
/// bằng thanh trạng thái, nội dung chỉ cuộn bên dưới dải đó; icon thanh trạng
/// thái chuyển sang màu tối cho dễ đọc trên nền sáng.
class StatusBarSafe extends StatelessWidget {
  final Widget child;
  final Color color;

  const StatusBarSafe({
    super.key,
    required this.child,
    this.color = AppColors.white,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Column(
        children: [
          Container(height: MediaQuery.paddingOf(context).top, color: color),
          Expanded(
            // Phần thân đã nằm dưới dải nên không cần chừa safe area trên nữa
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
