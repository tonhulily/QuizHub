import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/utils/time_format.dart';
import '../../data/models/media_item.dart';
import '../media/media_viewer.dart';
import '../../core/design_system/app_icons.dart';

/// Lưới ảnh/video của bài viết (1-4 ô, dư hiển thị "+N").
/// Mọi ảnh được cắt theo TRUNG TÂM (`BoxFit.cover` + `Alignment.center`).
class PostMediaGrid extends StatelessWidget {
  final List<MediaItem> media;
  final double spacing;

  const PostMediaGrid({super.key, required this.media, this.spacing = 2});

  @override
  Widget build(BuildContext context) {
    final items = media.where((m) => m.url.isNotEmpty).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    // Tràn hết chiều ngang, không bo góc (giống Facebook)
    return _layout(context, items);
  }

  Widget _layout(BuildContext context, List<MediaItem> items) {
    final extra = items.length - 4;
    Widget tile(int i, {bool withExtra = false}) => _MediaTile(
      item: items[i],
      extra: withExtra && extra > 0 ? extra : 0,
      onTap: () => MediaViewer.open(context, items, initialIndex: i),
    );

    switch (items.length) {
      case 1:
        final m = items.first;
        var ratio = (m.width != null && m.height != null && m.height! > 0)
            ? m.width! / m.height!
            : 4 / 3;
        ratio = ratio.clamp(0.8, 1.78);
        return AspectRatio(aspectRatio: ratio, child: tile(0));
      case 2:
        return AspectRatio(
          aspectRatio: 2 / 1.05,
          child: Row(
            children: [
              Expanded(child: tile(0)),
              SizedBox(width: spacing),
              Expanded(child: tile(1)),
            ],
          ),
        );
      case 3:
        return AspectRatio(
          aspectRatio: 1.25,
          child: Row(
            children: [
              Expanded(flex: 3, child: tile(0)),
              SizedBox(width: spacing),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Expanded(child: tile(1)),
                    SizedBox(height: spacing),
                    Expanded(child: tile(2)),
                  ],
                ),
              ),
            ],
          ),
        );
      default:
        return AspectRatio(
          aspectRatio: 1.15,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: tile(0)),
                    SizedBox(width: spacing),
                    Expanded(child: tile(1)),
                  ],
                ),
              ),
              SizedBox(height: spacing),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: tile(2)),
                    SizedBox(width: spacing),
                    Expanded(child: tile(3, withExtra: true)),
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _MediaTile extends StatelessWidget {
  final MediaItem item;
  final int extra;
  final VoidCallback onTap;

  const _MediaTile({required this.item, required this.onTap, this.extra = 0});

  @override
  Widget build(BuildContext context) {
    final preview = item.isVideo ? item.thumbnailUrl : item.url;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if ((preview ?? '').isNotEmpty)
            CachedNetworkImage(
              imageUrl: preview!,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              fadeInDuration: const Duration(milliseconds: 150),
              placeholder: (_, _) => Container(color: AppColors.neutral200),
              errorWidget: (_, _, _) => Container(
                color: AppColors.neutral200,
                child: const Icon(
                  AppIcons.imageBroken,
                  color: AppColors.neutral400,
                ),
              ),
            )
          else
            Container(color: AppColors.neutral800),
          if (item.isVideo) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0x99000000),
                  shape: BoxShape.circle,
                ),
                child: const Icon(AppIcons.play, color: Colors.white, size: 32),
              ),
            ),
            if (item.duration != null)
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xAA000000),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    TimeFormat.duration(item.duration!),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
          ],
          if (extra > 0)
            Container(
              color: const Color(0x99000000),
              alignment: Alignment.center,
              child: Text(
                '+$extra',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
