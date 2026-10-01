import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../../../data/models/catalog.dart';

//==============================================================================
// SPOCART — Size picker
//------------------------------------------------------------------------------
// Products that are sold in sizes must never reach the cart without one: the
// server rejects such a line at checkout. Every "Add to Cart" on a sized
// product opens this sheet first; SizeChip is shared with the product page.
//==============================================================================

/// Asks for one of [product.sizes]. Returns the chosen size, or null when the
/// sheet is dismissed — in which case the caller must not touch the cart.
Future<String?> showSizePickerSheet(
  BuildContext context,
  Product product, {
  String? selected,
  String confirmLabel = 'Add to Cart',
}) {
  return showAppBottomSheet<String>(
    context,
    title: 'Select size',
    builder: (context) => _SizePickerBody(
      product: product,
      initial: selected,
      confirmLabel: confirmLabel,
    ),
  );
}

class _SizePickerBody extends StatefulWidget {
  const _SizePickerBody({
    required this.product,
    required this.initial,
    required this.confirmLabel,
  });

  final Product product;
  final String? initial;
  final String confirmLabel;

  @override
  State<_SizePickerBody> createState() => _SizePickerBodyState();
}

class _SizePickerBodyState extends State<_SizePickerBody> {
  String? _size;

  @override
  void initState() {
    super.initState();
    final String? initial = widget.initial;
    _size = initial != null && widget.product.sizes.contains(initial)
        ? initial
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.product.name, style: AppTypography.bodyStrong),
          const SizedBox(height: 2),
          Text(
            'This product is sold in sizes. Pick one to continue.',
            style: AppTypography.small.copyWith(color: AppColors.textSoft),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final String s in widget.product.sizes)
                SizeChip(
                  label: s,
                  selected: _size == s,
                  onTap: () => setState(() => _size = s),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: widget.confirmLabel,
            onPressed: _size == null
                ? null
                : () => Navigator.of(context).pop(_size),
          ),
        ],
      ),
    );
  }
}

/// Outlined size pill, filled black when selected.
class SizeChip extends StatelessWidget {
  const SizeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.black : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.smAll,
        side: BorderSide(color: selected ? AppColors.black : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.smallStrong.copyWith(
              color: selected ? AppColors.white : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}
