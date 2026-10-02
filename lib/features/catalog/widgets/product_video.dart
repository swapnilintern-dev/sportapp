import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/media.dart';
import '../../../data/models/catalog.dart';

//==============================================================================
// SPOCART — Product video
//------------------------------------------------------------------------------
// The brand's own clip on YouTube, shown as its thumbnail with a play button.
// Tapping hands it to the YouTube app or the browser, which is deliberate: an
// embedded player would autoplay on a mobile connection, needs a plugin that
// does not cover web, iOS and Android equally, and would buffer behind the
// product details the buyer actually came for. The server only ever stores a
// validated YouTube link, so nothing else can be opened from here.
//==============================================================================

class ProductVideoSection extends StatelessWidget {
  const ProductVideoSection({super.key, required this.product});

  final Product product;

  Future<void> _play(BuildContext context) async {
    final Uri? uri = Uri.tryParse(product.videoUrl ?? '');
    if (uri == null || uri.scheme != 'https') return;
    final bool opened =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      showAppSnackBar(
        context,
        'Could not open the video. Check that you have a browser or the YouTube app.',
        tone: SnackTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!product.hasVideo) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            const Text('Product Video', style: AppTypography.h3),
            const SizedBox(width: AppSpacing.xs),
            const _PremiumBadge(),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: () => _play(context),
          borderRadius: AppRadius.mdAll,
          child: ClipRRect(
            borderRadius: AppRadius.mdAll,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductImage(
                    source: product.videoThumbnailUrl,
                    radius: 0,
                    fallbackIcon: Icons.play_circle_outline_rounded,
                    background: AppColors.surfaceAlt,
                  ),
                  // A soft scrim so the play button reads on any frame.
                  const DecoratedBox(
                    decoration: BoxDecoration(color: Color(0x33000000)),
                  ),
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: AppColors.white, size: 34),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Opens on YouTube.',
          style: AppTypography.caption.copyWith(color: AppColors.textSoft),
        ),
      ],
    );
  }
}

/// Small "Premium" marker beside the heading.
class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        'PREMIUM',
        style: AppTypography.caption.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
          fontSize: 9.5,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
