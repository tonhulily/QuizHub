import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/utils/time_format.dart';
import '../../data/models/media_item.dart';
import '../../core/design_system/app_icons.dart';

/// Xem ảnh / video toàn màn hình (trải nghiệm giống Facebook):
/// vuốt ngang để chuyển, pinch/double-tap để zoom, chạm để ẩn/hiện thanh công cụ,
/// vuốt xuống để đóng.
class MediaViewer extends StatefulWidget {
  final List<MediaItem> items;
  final int initialIndex;

  const MediaViewer({super.key, required this.items, this.initialIndex = 0});

  /// Mở viewer. [heroTagBuilder] (tuỳ chọn) để có hiệu ứng Hero từ thumbnail.
  static Future<void> open(
    BuildContext context,
    List<MediaItem> items, {
    int initialIndex = 0,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: AppColors.black,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, _, _) =>
            MediaViewer(items: items, initialIndex: initialIndex),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  bool _chromeVisible = true;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleChrome() => setState(() => _chromeVisible = !_chromeVisible);

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: Stack(
          children: [
            // Vuốt xuống để đóng (khi không zoom)
            GestureDetector(
              onVerticalDragEnd: (d) {
                if (!_zoomed && (d.primaryVelocity ?? 0) > 700) {
                  Navigator.of(context).pop();
                }
              },
              child: PageView.builder(
                controller: _controller,
                itemCount: total,
                physics: _zoomed
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                onPageChanged: (i) => setState(() {
                  _index = i;
                  _zoomed = false;
                }),
                itemBuilder: (_, i) {
                  final item = widget.items[i];
                  return item.isVideo
                      ? _VideoPage(
                          key: ValueKey('video_${item.url}'),
                          item: item,
                          active: i == _index,
                          onTap: _toggleChrome,
                        )
                      : _ImagePage(
                          item: item,
                          onTap: _toggleChrome,
                          onZoomChanged: (z) {
                            if (z != _zoomed) setState(() => _zoomed = z);
                          },
                        );
                },
              ),
            ),
            // Top bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              top: _chromeVisible ? 0 : -120,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + 4,
                  left: 4,
                  right: 16,
                  bottom: 12,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xAA000000), Color(0x00000000)],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(AppIcons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    if (total > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white20,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_index + 1}/$total',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePage extends StatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final ValueChanged<bool> onZoomChanged;

  const _ImagePage({
    required this.item,
    required this.onTap,
    required this.onZoomChanged,
  });

  @override
  State<_ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<_ImagePage>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<Matrix4>? _zoomAnim;
  Offset _doubleTapAt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_notifyZoom);
    _anim.addListener(() {
      if (_zoomAnim != null) _transform.value = _zoomAnim!.value;
    });
  }

  void _notifyZoom() {
    widget.onZoomChanged(_transform.value.getMaxScaleOnAxis() > 1.02);
  }

  @override
  void dispose() {
    _transform.removeListener(_notifyZoom);
    _transform.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    final zoomedIn = _transform.value.getMaxScaleOnAxis() > 1.02;
    final end = zoomedIn
        ? Matrix4.identity()
        : (Matrix4.identity()
            ..translateByDouble(
              -_doubleTapAt.dx * 1.5,
              -_doubleTapAt.dy * 1.5,
              0,
              1,
            )
            ..scaleByDouble(2.5, 2.5, 1, 1));
    _zoomAnim = Matrix4Tween(
      begin: _transform.value,
      end: end,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
      onDoubleTap: _onDoubleTap,
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: widget.item.url,
            fit: BoxFit.contain,
            placeholder: (_, _) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (_, _, _) => const Icon(
              AppIcons.imageBroken,
              color: Colors.white54,
              size: 56,
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  final MediaItem item;
  final bool active;
  final VoidCallback onTap;

  const _VideoPage({
    super.key,
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.item.url))
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _ready = true);
          if (widget.active) _controller.play();
        })
        .catchError((_) {
          if (mounted) setState(() => _failed = true);
        });
  }

  @override
  void didUpdateWidget(covariant _VideoPage old) {
    super.didUpdateWidget(old);
    if (!widget.active && _ready) _controller.pause();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    _controller.value.isPlaying ? _controller.pause() : _controller.play();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Text(
          'Không thể phát video',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    if (!_ready) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    final value = _controller.value;
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          if (!value.isPlaying)
            GestureDetector(
              onTap: _togglePlay,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: Color(0x88000000),
                  shape: BoxShape.circle,
                ),
                child: const Icon(AppIcons.play, color: Colors.white, size: 44),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: AppColors.primary500,
                    bufferedColor: AppColors.white50,
                    backgroundColor: AppColors.white20,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _togglePlay,
                      child: Icon(
                        value.isPlaying ? AppIcons.pause : AppIcons.play,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${TimeFormat.duration(value.position.inSeconds)} / '
                      '${TimeFormat.duration(value.duration.inSeconds)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
