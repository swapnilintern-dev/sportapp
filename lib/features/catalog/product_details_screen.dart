import 'package:flutter/material.dart';

import '../../app/app_navigator.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../data/models/catalog.dart';
import '../../state/cart_controller.dart';
import '../support/help_sheet.dart';
import 'widgets/product_widgets.dart';

//==============================================================================
// SPOCART — Product details
//------------------------------------------------------------------------------
// Gallery with wishlist toggle, price range + stock, key features, sizes,
// bulk-pricing link, description, related products and the Add to Cart /
// Buy Now bar. "Need help with this order?" opens the support sheet.
//==============================================================================

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key, required this.product});

  final Product product;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _imageIndex = 0;
  String? _size;

  Product get product => widget.product;

  bool get _needsSize => product.sizes.isNotEmpty && _size == null;

  void _addToCart() {
    if (_needsSize) {
      showAppSnackBar(context, 'Please select a size first.',
          tone: SnackTone.error);
      return;
    }
    addProductToCart(context, product, size: _size);
  }

  void _buyNow() {
    if (_needsSize) {
      showAppSnackBar(context, 'Please select a size first.',
          tone: SnackTone.error);
      return;
    }
    if (!product.inStock) {
      showAppSnackBar(context, '${product.name} is currently out of stock.',
          tone: SnackTone.error);
      return;
    }
    final CartController cart = AppScope.of(context).cart;
    if (cart.lineFor(product.id, size: _size) == null) {
      cart.add(product, size: _size);
    }
    AppNavigator.toCheckout(context);
  }

  void _toggleWishlist() {
    final WishlistController wishlist = AppScope.of(context).wishlist;
    final bool saved = wishlist.toggle(product.id);
    showAppSnackBar(
      context,
      saved ? 'Saved to wishlist' : 'Removed from wishlist',
      tone: saved ? SnackTone.success : SnackTone.neutral,
      actionLabel: saved ? 'View' : null,
      onAction: saved ? () => AppNavigator.toWishlist(context) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.of(context);
    final List<Product> related = services.catalog.related(product);
    final IconData fallback = productFallbackIcon(context, product);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ContentWidth(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Gallery(
                product: product,
                index: _imageIndex,
                onIndexChanged: (i) => setState(() => _imageIndex = i),
                fallback: fallback,
                wishlist: services.wishlist,
                onWishlist: _toggleWishlist,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xl),
              sliver: SliverList.list(
                children: [
                  Text(product.brand.toUpperCase(),
                      style: AppTypography.overline),
                  const SizedBox(height: 4),
                  Text(product.name, style: AppTypography.h1),
                  const SizedBox(height: AppSpacing.xs),
                  RatingStars(
                      rating: product.rating, reviewCount: product.reviewCount),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: formatInrRange(
                                product.bestPrice, product.basePrice),
                            style: AppTypography.priceLarge,
                            children: [
                              TextSpan(
                                text: ' / ${product.unit}',
                                style: AppTypography.small,
                              ),
                            ],
                          ),
                        ),
                      ),
                      StockPill(inStock: product.inStock),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _BulkPricingRow(product: product),
                  if (product.features.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const Text('Key Features', style: AppTypography.h3),
                    const SizedBox(height: AppSpacing.sm),
                    _FeatureRow(features: product.features),
                  ],
                  if (product.sizes.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const Text('Available Sizes', style: AppTypography.h3),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final String s in product.sizes)
                          _SizeChip(
                            label: s,
                            selected: _size == s,
                            onTap: () =>
                                setState(() => _size = _size == s ? null : s),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  const Text('About this product', style: AppTypography.h3),
                  const SizedBox(height: AppSpacing.xs),
                  Text(product.description, style: AppTypography.bodyMuted),
                  const SizedBox(height: AppSpacing.md),
                  _InfoLine(
                    icon: Icons.inventory_2_outlined,
                    text: 'Minimum order: ${product.moq} ${product.unit}',
                  ),
                  _InfoLine(
                    icon: Icons.receipt_long_outlined,
                    text: 'GST invoice provided on every order',
                  ),
                  if (product.customisable)
                    _InfoLine(
                      icon: Icons.brush_outlined,
                      text: 'Customisation available — logos, names, colours',
                      onTap: () => AppNavigator.toCustomOrder(context),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () => showHelpSheet(
                      context,
                      about: '${product.name} (MOQ ${product.moq} ${product.unit})',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.mdAll),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.headset_mic_outlined, size: 18),
                    label: const Text('Need help with this order?',
                        style: AppTypography.bodyStrong),
                  ),
                  if (related.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    const Text('You may also need', style: AppTypography.h3),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 236,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: related.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (context, i) =>
                            ProductCard(product: related[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: Row(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: services.cart,
                builder: (context, _) {
                  final int inCart =
                      services.cart.quantityOf(product.id, size: _size);
                  return SecondaryButton(
                    label: inCart > 0 ? 'In Cart · $inCart' : 'Add to Cart',
                    icon: inCart > 0
                        ? Icons.check_rounded
                        : Icons.add_shopping_cart_rounded,
                    onPressed: _addToCart,
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: PrimaryButton(
                label: 'Buy Now',
                onPressed: product.inStock ? _buyNow : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.product,
    required this.index,
    required this.onIndexChanged,
    required this.fallback,
    required this.wishlist,
    required this.onWishlist,
  });

  final Product product;
  final int index;
  final ValueChanged<int> onIndexChanged;
  final IconData fallback;
  final WishlistController wishlist;
  final VoidCallback onWishlist;

  @override
  Widget build(BuildContext context) {
    final List<String> images =
        product.images.isEmpty ? <String>[''] : product.images;
    final double topInset = MediaQuery.paddingOf(context).top;

    return Column(
      children: [
        Stack(
          children: [
            AspectRatio(
              aspectRatio: 1.15,
              child: PageView.builder(
                itemCount: images.length,
                onPageChanged: onIndexChanged,
                itemBuilder: (context, i) => ProductImage(
                  source: images[i],
                  radius: 0,
                  fallbackIcon: fallback,
                  background: AppColors.surface,
                ),
              ),
            ),
            Positioned(
              top: topInset + AppSpacing.xs,
              left: AppSpacing.xs,
              child: AppIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                background: AppColors.white,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            Positioned(
              top: topInset + AppSpacing.xs,
              right: AppSpacing.xs,
              child: ListenableBuilder(
                listenable: wishlist,
                builder: (context, _) {
                  final bool saved = wishlist.contains(product.id);
                  return AppIconButton(
                    icon: saved
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    tooltip: saved ? 'Remove from wishlist' : 'Save to wishlist',
                    background: AppColors.white,
                    color: saved ? AppColors.red : AppColors.text,
                    onPressed: onWishlist,
                  );
                },
              ),
            ),
            if (images.length > 1)
              Positioned(
                bottom: AppSpacing.sm,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < images.length; i++)
                      AnimatedContainer(
                        duration: AppDurations.fast,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == index ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == index ? AppColors.red : AppColors.white,
                          borderRadius: AppRadius.pillAll,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        if (images.length > 1)
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page, AppSpacing.sm, AppSpacing.page, 0),
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => onIndexChanged(i),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.smAll,
                    border: Border.all(
                      color: i == index ? AppColors.red : AppColors.border,
                      width: i == index ? 1.6 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: ProductImage(
                    source: images[i],
                    size: 54,
                    radius: AppRadius.sm - 2,
                    fallbackIcon: fallback,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BulkPricingRow extends StatelessWidget {
  const _BulkPricingRow({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => AppNavigator.toBulkPricing(context, product),
      color: AppColors.surface,
      borderColor: AppColors.surface,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.layers_outlined, color: AppColors.red, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bulk Pricing / MOQ', style: AppTypography.title),
                Text(
                  'MOQ ${product.moq} ${product.unit} · from ${formatInr(product.bestPrice)} at ${product.tiers.last.minQty}+',
                  style: AppTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.features});

  final List<ProductFeature> features;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < features.length && i < 3; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Icon(features[i].icon, color: AppColors.red, size: 22),
                  const SizedBox(height: 6),
                  Text(
                    features[i].label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({
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

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text, this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSoft),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: Text(text, style: AppTypography.small)),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
