import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

//==============================================================================
// SPOCART — Layout primitives
//------------------------------------------------------------------------------
// AppScaffold     — page chrome: app bar, content width cap, bottom action bar.
// AppCard         — bordered white card used for products, addresses, orders.
// SectionHeader   — "Popular Products      View All".
// BottomActionBar — CTA strip pinned above the home indicator.
// ContentWidth    — caps width on tablets / landscape so phone layouts hold.
//==============================================================================

class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Symmetric padding (rather than Align) keeps the incoming height
    // constraints tight, so scrollables inside still fill the screen.
    return LayoutBuilder(
      builder: (context, constraints) {
        final double extra = constraints.maxWidth - AppSizes.maxContentWidth;
        if (extra <= 0 || !constraints.hasBoundedWidth) return child;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: extra / 2),
          child: child,
        );
      },
    );
  }
}

/// Standard app bar: bold title (or custom [titleWidget]), optional back
/// button and trailing actions. Height and colours come from the theme.
class SpocartAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SpocartAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.showBack = true,
    this.onBack,
    this.bottom,
    this.centerTitle = false,
    this.backgroundColor,
  });

  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;
  final Color? backgroundColor;

  @override
  Size get preferredSize => Size.fromHeight(
        AppSizes.appBarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final bool canPop = showBack && Navigator.of(context).canPop();
    return AppBar(
      backgroundColor: backgroundColor,
      centerTitle: centerTitle,
      titleSpacing: canPop ? 0 : AppSpacing.page,
      leading: canPop
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back',
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          : null,
      automaticallyImplyLeading: false,
      title: titleWidget ??
          (title == null
              ? null
              : Text(
                  title!,
                  style: AppTypography.h3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )),
      actions: actions == null
          ? null
          : [...actions!, const SizedBox(width: AppSpacing.xs)],
      bottom: bottom,
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.margin,
    this.onTap,
    this.color = AppColors.white,
    this.borderColor = AppColors.border,
    this.radius = AppRadius.lg,
    this.shadow = false,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final double radius;
  final bool shadow;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final BorderRadius br = BorderRadius.circular(radius);
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: br,
        child: content,
      );
    }
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: br,
        border: Border.all(color: borderColor),
        boxShadow: shadow ? AppShadows.card : null,
      ),
      clipBehavior: clip || onTap != null ? Clip.antiAlias : Clip.none,
      child: Material(
        color: Colors.transparent,
        child: content,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = AppSpacing.pagePadding,
    this.subtitle,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.h3),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppTypography.small),
                ],
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.red,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!, style: AppTypography.smallStrong.copyWith(color: AppColors.red)),
            ),
        ],
      ),
    );
  }
}

/// A CTA strip pinned to the bottom of a screen. Pads for the home indicator
/// and casts a soft shadow upwards so it reads as a fixed bar over content.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.sm,
    ),
    this.color = AppColors.white,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        boxShadow: AppShadows.bottomBar,
        border: const Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: padding,
          child: ContentWidth(child: child),
        ),
      ),
    );
  }
}

/// Small rounded pill with a tinted background: "In Stock", "Shipped", "Home".
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.color = AppColors.success,
    this.background,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color color;
  final Color? background;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: color),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: dense ? 10.5 : 11.5,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Key/value row used on summaries: "Subtotal ...... ₹22,000".
class SummaryRow extends StatelessWidget {
  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasized = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasized;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle =
        emphasized ? AppTypography.h3 : AppTypography.bodyMuted;
    final TextStyle valueStyle = emphasized
        ? AppTypography.h3.copyWith(color: valueColor ?? AppColors.text)
        : AppTypography.bodyStrong.copyWith(color: valueColor);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}

/// A circular avatar with initials, used for the account tab and addresses.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.initials,
    this.size = 56,
    this.background = AppColors.black,
    this.foreground = AppColors.white,
  });

  final String initials;
  final double size;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: foreground,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Dismisses the keyboard when the user taps outside a field.
class KeyboardDismisser extends StatelessWidget {
  const KeyboardDismisser({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}
