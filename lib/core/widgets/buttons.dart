import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

//==============================================================================
// SPOCART — Buttons
//------------------------------------------------------------------------------
// PrimaryButton   — red filled, the one CTA per screen. Supports loading.
// SecondaryButton — outlined, for the alternative action next to a primary.
// GhostButton     — text-only link style ("Skip for now", "View All").
// AddToCartButton — compact outlined red "+ Add to Cart" used on cards.
//==============================================================================

enum ButtonSize { regular, small }

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.size = ButtonSize.regular,
    this.expand = true,
    this.color = AppColors.red,
    this.foregroundColor = AppColors.white,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final ButtonSize size;
  final bool expand;
  final Color color;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !loading;
    final double height = size == ButtonSize.regular
        ? AppSizes.buttonHeight
        : AppSizes.buttonHeightSmall;
    final TextStyle style = size == ButtonSize.regular
        ? AppTypography.button
        : AppTypography.buttonSmall;

    final Widget child = AnimatedSwitcher(
      duration: AppDurations.fast,
      child: loading
          ? SizedBox(
              key: const ValueKey('loading'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
              ),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: foregroundColor),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: style.copyWith(color: foregroundColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );

    final Widget button = SizedBox(
      height: height,
      width: expand ? double.infinity : null,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: color.withValues(alpha: 0.45),
          disabledForegroundColor: foregroundColor.withValues(alpha: 0.9),
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: size == ButtonSize.regular ? AppSpacing.lg : AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
        child: child,
      ),
    );
    return button;
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.size = ButtonSize.regular,
    this.expand = true,
    this.color = AppColors.red,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonSize size;
  final bool expand;
  final Color color;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !loading;
    final double height = size == ButtonSize.regular
        ? AppSizes.buttonHeight
        : AppSizes.buttonHeightSmall;
    final TextStyle style = size == ButtonSize.regular
        ? AppTypography.button
        : AppTypography.buttonSmall;

    return SizedBox(
      height: height,
      width: expand ? double.infinity : null,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          disabledForegroundColor: color.withValues(alpha: 0.45),
          side: BorderSide(
            color: enabled ? color : color.withValues(alpha: 0.4),
            width: 1.4,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: size == ButtonSize.regular ? AppSpacing.lg : AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: style,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.red,
    this.icon,
    this.style,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style ?? AppTypography.smallStrong.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact "+ Add to Cart" used on product cards and list rows. Flips to a
/// filled "In Cart · n" state so a buyer can see what is already added.
class AddToCartButton extends StatelessWidget {
  const AddToCartButton({
    super.key,
    required this.onPressed,
    this.inCartQuantity = 0,
    this.compact = true,
  });

  final VoidCallback? onPressed;
  final int inCartQuantity;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool inCart = inCartQuantity > 0;
    final String label = inCart ? 'In Cart · $inCartQuantity' : 'Add to Cart';

    final TextStyle textStyle = AppTypography.buttonSmall.copyWith(fontSize: 12);
    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(inCart ? Icons.check_rounded : Icons.add_rounded, size: 15),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    return SizedBox(
      height: compact ? 32 : AppSizes.buttonHeightSmall,
      child: inCart
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: AppColors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
                textStyle: textStyle,
              ),
              child: content,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.red,
                side: const BorderSide(color: AppColors.red, width: 1.2),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
                textStyle: textStyle,
              ),
              child: content,
            ),
    );
  }
}

/// Circular icon button used in app bars and on image overlays.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.badgeCount = 0,
    this.background,
    this.color = AppColors.text,
    this.size = AppSizes.iconButton,
    this.iconSize = 22,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final int badgeCount;
  final Color? background;
  final Color color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final Widget button = Material(
      color: background ?? Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: color),
        ),
      ),
    );

    final Widget withBadge = badgeCount > 0
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              button,
              Positioned(
                top: 4,
                right: 2,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: AppRadius.pillAll,
                      border: Border.all(color: AppColors.white, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )
        : button;

    if (tooltip == null) return withBadge;
    return Tooltip(message: tooltip!, child: withBadge);
  }
}
