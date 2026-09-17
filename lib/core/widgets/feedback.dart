import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'buttons.dart';
import 'layout.dart';

//==============================================================================
// SPOCART — Snackbars, dialogs and bottom sheets
//------------------------------------------------------------------------------
// One vocabulary for feedback so every screen reads the same.
//==============================================================================

enum SnackTone { neutral, success, error }

void showAppSnackBar(
  BuildContext context,
  String message, {
  SnackTone tone = SnackTone.neutral,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  final (Color background, IconData icon) = switch (tone) {
    SnackTone.neutral => (AppColors.ink, Icons.info_outline_rounded),
    SnackTone.success => (AppColors.success, Icons.check_circle_outline_rounded),
    SnackTone.error => (AppColors.red, Icons.error_outline_rounded),
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: background,
        duration: duration,
        // Snackbars with an action persist by default; ours are transient hints.
        persist: false,
        content: Row(
          children: [
            Icon(icon, color: AppColors.white, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodyStrong.copyWith(color: AppColors.white),
              ),
            ),
          ],
        ),
        action: actionLabel == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: AppColors.white,
                onPressed: onAction ?? () {},
              ),
      ),
    );
}

/// Confirmation dialog. Resolves true when the destructive/primary action is
/// chosen, false otherwise (including barrier dismiss).
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: destructive ? AppColors.red : AppColors.text),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(child: Text(title, style: AppTypography.h3)),
        ],
      ),
      content: Text(message, style: AppTypography.bodyMuted),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSoft),
          child: Text(cancelLabel, style: AppTypography.bodyStrong.copyWith(color: AppColors.textSoft)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: destructive ? AppColors.red : AppColors.black,
            foregroundColor: AppColors.white,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          ),
          child: Text(confirmLabel, style: AppTypography.bodyStrong.copyWith(color: AppColors.white)),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Rounded modal bottom sheet with a drag handle, optional title and close.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  bool isScrollControlled = true,
  bool showClose = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    backgroundColor: AppColors.white,
    builder: (context) => Padding(
      // Lifts the sheet above the keyboard for sheets that contain inputs.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: ContentWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: AppRadius.pillAll,
                ),
              ),
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.md, AppSpacing.xs, 0),
                  child: Row(
                    children: [
                      Expanded(child: Text(title, style: AppTypography.h2)),
                      if (showClose)
                        AppIconButton(
                          icon: Icons.close_rounded,
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                    ],
                  ),
                ),
              Flexible(
                child: SafeArea(
                  top: false,
                  child: builder(context),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A list row for option sheets: icon, title, subtitle, chevron.
class SheetOptionTile extends StatelessWidget {
  const SheetOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor = AppColors.red,
    this.iconBackground = AppColors.redTint,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color iconColor;
  final Color iconBackground;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: AppRadius.mdAll,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.title),
                  if (subtitle != null)
                    Text(subtitle!, style: AppTypography.small),
                ],
              ),
            ),
            trailing ??
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
