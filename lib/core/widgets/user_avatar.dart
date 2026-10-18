import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../design_system/app_colors.dart';
import '../design_system/component_tokens.dart';

/// Avatar tròn có hỗ trợ khung vinh danh (`frame_url`) và chữ cái đầu khi
/// chưa có ảnh. Dùng cho mọi nơi hiển thị người dùng.
class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? frameUrl;
  final String name;
  final double size;
  final VoidCallback? onTap;
  final bool showBorder;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    this.frameUrl,
    this.name = '',
    this.size = ComponentTokens.avatarMD,
    this.onTap,
    this.showBorder = false,
  });

  String get _initial {
    final t = name.trim();
    if (t.isEmpty) return '?';
    final parts = t.split(RegExp(r'\s+'));
    return parts.last.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasFrame = (frameUrl ?? '').isNotEmpty;
    // Khung nằm đè lên avatar nên phóng to lớp ngoài một chút
    final frameExtra = hasFrame ? size * 0.24 : 0.0;

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary100,
        border: showBorder
            ? Border.all(color: AppColors.white, width: size * 0.04 + 1.5)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: (avatarUrl ?? '').isEmpty
          ? _placeholder(context)
          : CachedNetworkImage(
              imageUrl: avatarUrl!,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 150),
              placeholder: (_, _) => _placeholder(context),
              errorWidget: (_, _, _) => _placeholder(context),
            ),
    );

    Widget result = SizedBox(
      width: size + frameExtra,
      height: size + frameExtra,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          avatar,
          if (hasFrame)
            Positioned.fill(
              child: IgnorePointer(
                child: CachedNetworkImage(
                  imageUrl: frameUrl!,
                  fit: BoxFit.contain,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                  placeholder: (_, _) => const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
    );

    if (onTap != null) {
      result = GestureDetector(onTap: onTap, child: result);
    }
    return result;
  }

  Widget _placeholder(BuildContext context) => Center(
    child: Text(
      _initial,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: AppColors.primary700,
        fontWeight: FontWeight.w700,
        fontSize: size * 0.42,
      ),
    ),
  );
}
