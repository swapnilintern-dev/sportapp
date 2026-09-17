import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../data/models/catalog.dart';
import '../../data/models/engagement.dart';
import '../../state/cart_controller.dart';
import '../quotes/request_quote_sheet.dart';
import 'widgets/product_widgets.dart';

//==============================================================================
// SPOCART — Bulk Pricing / MOQ
//------------------------------------------------------------------------------
// The slab table for one product, a quantity picker that shows the live
// per-unit price, Add to Cart at that quantity, and Request for Quote.
//==============================================================================

class BulkPricingScreen extends StatefulWidget {
  const BulkPricingScreen({super.key, required this.product});

  final Product product;

  @override
  State<BulkPricingScreen> createState() => _BulkPricingScreenState();
}

class _BulkPricingScreenState extends State<BulkPricingScreen> {
  late int _qty = widget.product.moq;

  Product get product => widget.product;

  int _tierIndexFor(int qty) {
    int index = 0;
    for (int i = 0; i < product.tiers.length; i++) {
      if (qty >= product.tiers[i].minQty) index = i;
    }
    return index;
  }

  void _addToCart() {
    final CartController cart = AppScope.of(context).cart;
    final int existing = cart.quantityOf(product.id);
    if (existing > 0) {
      final line = cart.lineFor(product.id);
      if (line != null) cart.setQuantity(line, _qty);
    } else {
      cart.add(product, qty: _qty);
    }
    showCartSnack(context, '$_qty × ${product.name} in cart');
  }

  Future<void> _requestQuote() async {
    final QuoteRequest? quote =
        await showRequestQuoteSheet(context, product: product);
    if (quote != null && mounted) confirmQuoteSubmitted(context, quote);
  }

  @override
  Widget build(BuildContext context) {
    final int activeTier = _tierIndexFor(_qty);
    final double unit = product.priceForQuantity(_qty);
    final IconData fallback = productFallbackIcon(context, product);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SpocartAppBar(title: 'Bulk Pricing'),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            AppCard(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ProductImage(
                    source: product.primaryImage,
                    size: 72,
                    fallbackIcon: fallback,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name,
                            style: AppTypography.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('MOQ: ${product.moq} ${product.unit}',
                            style: AppTypography.small),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _TierTable(
              product: product,
              activeIndex: activeTier,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Prices may vary based on brand and customisation. All prices exclude 18% GST.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text('Your quantity', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  QuantityStepper(
                    value: _qty,
                    min: product.moq,
                    onChanged: (v) => setState(() => _qty = v),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${formatInr(unit)} / ${product.unit}',
                            style: AppTypography.price),
                        Text(
                          'Total ${formatInr(unit * _qty)} + GST',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _QuickQuantities(
              product: product,
              selected: _qty,
              onPick: (q) => setState(() => _qty = q),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryButton(
              label: 'Add to Cart',
              icon: Icons.add_shopping_cart_rounded,
              onPressed: product.inStock ? _addToCart : null,
            ),
            const SizedBox(height: AppSpacing.xs),
            SecondaryButton(
              label: 'Request for Quote',
              icon: Icons.request_quote_outlined,
              onPressed: _requestQuote,
            ),
          ],
        ),
      ),
    );
  }
}

class _TierTable extends StatelessWidget {
  const _TierTable({required this.product, required this.activeIndex});

  final Product product;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: AppColors.black,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text('Quantity',
                      style: AppTypography.smallStrong
                          .copyWith(color: AppColors.white)),
                ),
                Text('Price (per ${product.unit})',
                    style: AppTypography.smallStrong
                        .copyWith(color: AppColors.white)),
              ],
            ),
          ),
          for (int i = 0; i < product.tiers.length; i++)
            Container(
              color: i == activeIndex ? AppColors.redTint : AppColors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(product.tierRangeLabel(i),
                            style: AppTypography.bodyStrong),
                        if (i == activeIndex) ...[
                          const SizedBox(width: 8),
                          const StatusPill(
                              label: 'Your slab', color: AppColors.red, dense: true),
                        ],
                      ],
                    ),
                  ),
                  Text(formatInr(product.tiers[i].unitPrice),
                      style: AppTypography.bodyStrong.copyWith(
                          color: i == activeIndex
                              ? AppColors.red
                              : AppColors.text)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickQuantities extends StatelessWidget {
  const _QuickQuantities({
    required this.product,
    required this.selected,
    required this.onPick,
  });

  final Product product;
  final int selected;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final PriceTier t in product.tiers)
          ChoiceChip(
            label: Text('${t.minQty} ${product.unit}'),
            selected: selected == t.minQty,
            onSelected: (_) => onPick(t.minQty),
            selectedColor: AppColors.black,
            labelStyle: AppTypography.smallStrong.copyWith(
              color: selected == t.minQty ? AppColors.white : AppColors.text,
            ),
            side: BorderSide(
              color: selected == t.minQty ? AppColors.black : AppColors.border,
            ),
            showCheckmark: false,
          ),
      ],
    );
  }
}
