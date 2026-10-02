import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/media.dart';
import '../../../data/models/engagement.dart';
import '../image_viewer_screen.dart';

//==============================================================================
// SPOCART — Review widgets
//------------------------------------------------------------------------------
// RatingSummary — the average, the count and the star distribution.
// ReviewTile    — one review, with its photos and a "Verified buyer" mark.
// StarPicker    — the input used by the write-a-review sheet.
//==============================================================================

class RatingSummary extends StatelessWidget {
  const RatingSummary({super.key, required this.page});

  final ReviewPage page;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surface,
      borderColor: AppColors.surface,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(page.average.toStringAsFixed(1), style: AppTypography.h1),
              RatingStars(rating: page.average, size: 13),
              const SizedBox(height: 2),
              Text(
                '${page.total} review${page.total == 1 ? '' : 's'}',
                style: AppTypography.caption,
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int star = 5; star >= 1; star--)
                  _DistributionRow(
                    star: star,
                    count: page.breakdown[star] ?? 0,
                    total: page.total,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.star,
    required this.count,
    required this.total,
  });

  final int star;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final double fraction = total == 0 ? 0 : count / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: Text('$star', style: AppTypography.caption),
          ),
          const Icon(Icons.star_rounded, size: 11, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadius.pillAll,
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 5,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.red),
              ),
            ),
          ),
          SizedBox(
            width: 26,
            child: Text(
              '$count',
              textAlign: TextAlign.end,
              style: AppTypography.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class ReviewTile extends StatelessWidget {
  const ReviewTile({
    super.key,
    required this.review,
    this.onEdit,
    this.onDelete,
  });

  final ProductReview review;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  String get _when {
    final Duration ago = DateTime.now().difference(review.createdAt);
    if (ago.inDays >= 365) return '${ago.inDays ~/ 365}y ago';
    if (ago.inDays >= 30) return '${ago.inDays ~/ 30}mo ago';
    if (ago.inDays >= 1) return '${ago.inDays}d ago';
    if (ago.inHours >= 1) return '${ago.inHours}h ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RatingStars(rating: review.rating.toDouble(), size: 13),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  review.mine ? 'Your review' : review.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.smallStrong,
                ),
              ),
              Text(_when, style: AppTypography.caption),
            ],
          ),
          if (review.verifiedBuyer) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.verified_rounded,
                    size: 13, color: AppColors.success),
                const SizedBox(width: 4),
                Text(
                  'Verified buyer',
                  style: AppTypography.caption.copyWith(color: AppColors.success),
                ),
              ],
            ),
          ],
          if (review.title.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(review.title, style: AppTypography.bodyStrong),
          ],
          const SizedBox(height: 4),
          Text(review.body, style: AppTypography.body),
          if (review.photos.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => showProductImageViewer(
                    context,
                    images: review.photos,
                    initialIndex: i,
                    title: review.mine ? 'Your review' : review.author,
                  ),
                  child: ProductImage(source: review.photos[i], size: 64),
                ),
              ),
            ),
          ],
          if (review.mine && (onEdit != null || onDelete != null)) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                if (onEdit != null)
                  GhostButton(label: 'Edit', onPressed: onEdit),
                if (onDelete != null)
                  GhostButton(
                    label: 'Delete',
                    color: AppColors.red,
                    onPressed: onDelete,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Tap a star to set the rating. Used by the write-a-review sheet.
class StarPicker extends StatelessWidget {
  const StarPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 36,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  static const List<String> _labels = <String>[
    'Tap to rate',
    'Poor',
    'Not great',
    'Okay',
    'Good',
    'Excellent',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (int star = 1; star <= 5; star++)
              IconButton(
                onPressed: () => onChanged(star),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                constraints: const BoxConstraints(),
                tooltip: _labels[star],
                icon: Icon(
                  star <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: size,
                  color: star <= value ? AppColors.red : AppColors.textMuted,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(_labels[value.clamp(0, 5)], style: AppTypography.caption),
      ],
    );
  }
}
