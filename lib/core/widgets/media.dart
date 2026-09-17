import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

//==============================================================================
// SPOCART — Images & brand marks
//------------------------------------------------------------------------------
// ProductImage — rounded asset/network image with a stable placeholder so a
//                missing file never shows as a broken tile.
// BrandLogo    — the SPOCART wordmark (dark or light variant).
//==============================================================================

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.source,
    this.size,
    this.width,
    this.height,
    this.radius = AppRadius.md,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.sports_rounded,
    this.background = AppColors.surface,
  });

  /// An asset path ("assets/images/x.jpg") or an http(s) URL.
  final String? source;
  final double? size;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;
  final IconData fallbackIcon;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final double? w = size ?? width;
    final double? h = size ?? height;

    Widget placeholder() => Container(
          width: w,
          height: h,
          color: background,
          alignment: Alignment.center,
          child: Icon(
            fallbackIcon,
            size: (h ?? 48) * 0.4,
            color: AppColors.textMuted,
          ),
        );

    final String? src = source;
    Widget image;
    if (src == null || src.isEmpty) {
      image = placeholder();
    } else if (src.startsWith('http')) {
      image = Image.network(
        src,
        width: w,
        height: h,
        fit: fit,
        errorBuilder: (_, _, _) => placeholder(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder(),
      );
    } else {
      image = Image.asset(
        src,
        width: w,
        height: h,
        fit: fit,
        // Decode at display size to keep memory low in long lists.
        cacheWidth: w == null
            ? null
            : (w * MediaQuery.devicePixelRatioOf(context)).round(),
        errorBuilder: (_, _, _) => placeholder(),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: w, height: h, child: image),
    );
  }
}

enum BrandLogoVariant { dark, light }

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.variant = BrandLogoVariant.dark,
    this.height = 36,
  });

  final BrandLogoVariant variant;
  final double height;

  @override
  Widget build(BuildContext context) {
    final String asset = variant == BrandLogoVariant.dark
        ? 'assets/brand/logo_dark.png'
        : 'assets/brand/logo_light.png';
    return Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      semanticLabel: 'SPOCART',
      errorBuilder: (_, _, _) => Text(
        'SPOCART',
        style: TextStyle(
          fontSize: height * 0.6,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          color: variant == BrandLogoVariant.dark
              ? AppColors.black
              : AppColors.white,
        ),
      ),
    );
  }
}

/// Decorative rating stars, e.g. ★★★★☆ 4.5 (124 reviews).
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.rating,
    this.size = 14,
    this.reviewCount,
  });

  final double rating;
  final double size;
  final int? reviewCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= 5; i++)
          Icon(
            i <= rating.floor()
                ? Icons.star_rounded
                : (i - rating) < 1
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            size: size,
            color: AppColors.star,
          ),
        const SizedBox(width: 4),
        Text(
          reviewCount == null
              ? rating.toStringAsFixed(1)
              : '${rating.toStringAsFixed(1)} ($reviewCount reviews)',
          style: TextStyle(
            fontSize: size * 0.86,
            fontWeight: FontWeight.w600,
            color: AppColors.textSoft,
          ),
        ),
      ],
    );
  }
}

/// − n + stepper used in the cart and on product details.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 9999,
    this.compact = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double h = compact ? 30 : 36;
    return Container(
      height: h,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.smAll,
        color: AppColors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            enabled: value > min,
            onTap: () => onChanged((value - 1).clamp(min, max)),
            size: h,
          ),
          SizedBox(
            width: compact ? 36 : 44,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 13 : 14,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            enabled: value < max,
            onTap: () => onChanged((value + 1).clamp(min, max)),
            size: h,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.size,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: AppRadius.smAll,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.text : AppColors.border,
        ),
      ),
    );
  }
}
