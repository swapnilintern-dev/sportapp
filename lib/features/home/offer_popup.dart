import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_navigator.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/media.dart';
import '../../data/models/catalog.dart';
import '../../data/models/engagement.dart';

//==============================================================================
// SPOCART — Offer popup
//------------------------------------------------------------------------------
// The one live offer, shown a few seconds after Home settles so it never lands
// on top of a buyer mid-tap. It closes itself if left alone, offers "Don't show
// again today", and is shown at most once per launch. Where it leads was
// checked by the server when the offer was saved, so this screen only routes.
//==============================================================================

/// How long Home is left alone before the offer appears.
const Duration _showAfter = Duration(seconds: 5);

/// How long the offer waits before closing itself.
const Duration _autoDismissAfter = Duration(seconds: 12);

/// Shows the live offer if there is one to show. Safe to call on every Home
/// build: the controller only ever hands it over once per launch.
Future<void> maybeShowOfferPopup(BuildContext context) async {
  final AppServices services = AppScope.of(context);
  final Promotion? promotion = await services.promotions.takePending();
  if (promotion == null || !context.mounted) return;

  await Future<void>.delayed(_showAfter);
  if (!context.mounted) return;

  // Never land on top of another dialog, sheet or a pushed screen.
  if (ModalRoute.of(context)?.isCurrent != true) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => _OfferDialog(promotion: promotion),
  );
}

class _OfferDialog extends StatefulWidget {
  const _OfferDialog({required this.promotion});

  final Promotion promotion;

  @override
  State<_OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends State<_OfferDialog> {
  Timer? _autoDismiss;
  bool _dontShowAgain = false;

  Promotion get promotion => widget.promotion;

  @override
  void initState() {
    super.initState();
    _autoDismiss = Timer(_autoDismissAfter, () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    super.dispose();
  }

  /// Any interaction means the buyer is reading it — stop the auto-close.
  void _keepOpen() {
    _autoDismiss?.cancel();
    _autoDismiss = null;
  }

  Future<void> _close() async {
    if (_dontShowAgain) {
      await AppScope.of(context).promotions.dismissForToday(promotion.id);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _follow() async {
    _keepOpen();
    final AppServices services = AppScope.of(context);
    if (_dontShowAgain) {
      await services.promotions.dismissForToday(promotion.id);
    }
    if (!mounted) return;
    Navigator.of(context).pop();

    final String target = promotion.linkTarget ?? '';
    switch (promotion.link) {
      case PromotionLink.product:
        await AppNavigator.toProductById(context, target);
      case PromotionLink.category:
        final ProductCategory? category = services.catalog.categoryById(target);
        if (category != null && context.mounted) {
          await AppNavigator.toCategory(context, category);
        }
      case PromotionLink.url:
        // Only https links are stored, so this can never open a scheme the
        // buyer did not expect.
        final Uri? uri = Uri.tryParse(target);
        if (uri != null && uri.scheme == 'https') {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      case PromotionLink.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onTap: _keepOpen,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if ((promotion.imageUrl ?? '').isNotEmpty)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ProductImage(
                    source: promotion.imageUrl,
                    radius: 0,
                    fallbackIcon: Icons.local_offer_outlined,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md,
                    AppSpacing.lg, AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_offer_rounded,
                            size: 18, color: AppColors.red),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(promotion.title,
                              style: AppTypography.h3, maxLines: 2),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(promotion.body, style: AppTypography.bodyMuted),
                    const SizedBox(height: AppSpacing.md),
                    if (promotion.hasAction)
                      PrimaryButton(
                        label: promotion.actionLabel,
                        onPressed: _follow,
                      ),
                    const SizedBox(height: AppSpacing.xs),
                    GhostButton(label: 'Close', onPressed: _close),
                    CheckboxListTile(
                      value: _dontShowAgain,
                      onChanged: (bool? v) {
                        _keepOpen();
                        setState(() => _dontShowAgain = v ?? false);
                      },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      activeColor: AppColors.red,
                      title: const Text("Don't show this again today",
                          style: AppTypography.caption),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
