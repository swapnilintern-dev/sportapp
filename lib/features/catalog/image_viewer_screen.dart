import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';

//==============================================================================
// SPOCART — Full-screen image viewer
//------------------------------------------------------------------------------
// Opened by tapping a product photo. Swipe between images, pinch to zoom,
// double-tap to zoom in and out. Each page keeps its own transform and is
// reset when it scrolls away, so the next photo always opens at fit size.
//==============================================================================

Future<void> showProductImageViewer(
  BuildContext context, {
  required List<String> images,
  required int initialIndex,
  required String title,
  IconData fallbackIcon = Icons.sports_rounded,
}) {
  final List<String> shown = images
      .where((String s) => s.trim().isNotEmpty)
      .toList(growable: false);
  if (shown.isEmpty) return Future<void>.value();
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ImageViewerScreen(
        images: shown,
        initialIndex: initialIndex.clamp(0, shown.length - 1),
        title: title,
        fallbackIcon: fallbackIcon,
      ),
    ),
  );
}

class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({
    super.key,
    required this.images,
    required this.title,
    this.initialIndex = 0,
    this.fallbackIcon = Icons.sports_rounded,
  });

  final List<String> images;
  final String title;
  final int initialIndex;
  final IconData fallbackIcon;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: widget.images.length,
            onPageChanged: (int i) => setState(() => _index = i),
            itemBuilder: (context, i) => _ZoomableImage(
              source: widget.images[i],
              fallbackIcon: widget.fallbackIcon,
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + AppSpacing.xs,
            left: AppSpacing.xs,
            right: AppSpacing.xs,
            child: Row(
              children: [
                AppIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  background: AppColors.white,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.smallStrong.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                ),
                if (widget.images.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: Text(
                      '${_index + 1} / ${widget.images.length}',
                      style: AppTypography.smallStrong.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One page: pinch to zoom, double-tap to toggle 1× / 2.5× at the tap point.
class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({required this.source, required this.fallbackIcon});

  final String source;
  final IconData fallbackIcon;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final TransformationController _transform = TransformationController();

  static const double _zoomedScale = 2.5;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom(TapDownDetails details) {
    final bool zoomedIn = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomedIn) {
      _transform.value = Matrix4.identity();
      return;
    }
    final Offset at = details.localPosition;
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        -at.dx * (_zoomedScale - 1),
        -at.dy * (_zoomedScale - 1),
        0,
        1,
      )
      ..scaleByDouble(_zoomedScale, _zoomedScale, _zoomedScale, 1);
  }

  @override
  Widget build(BuildContext context) {
    final String src = widget.source;
    final Widget image = src.startsWith('http')
        ? Image.network(
            src,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                _placeholder('This photo could not be loaded.'),
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(color: AppColors.white),
                  ),
          )
        : Image.asset(
            src,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                _placeholder('This photo could not be loaded.'),
          );

    return GestureDetector(
      onDoubleTapDown: _toggleZoom,
      // The handler runs on onDoubleTapDown; this keeps the gesture recognised.
      onDoubleTap: () {},
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 5,
        child: Center(child: image),
      ),
    );
  }

  Widget _placeholder(String message) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(widget.fallbackIcon, size: 64, color: AppColors.textMuted),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          style: AppTypography.small.copyWith(color: AppColors.textMuted),
        ),
      ],
    ),
  );
}
