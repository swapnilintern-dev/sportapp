import 'package:flutter/material.dart';

import '../../../app/app_navigator.dart';
import '../../../app/app_scope.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/media.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/catalog.dart';
import '../../../state/cart_controller.dart';
import 'size_picker.dart';

//==============================================================================
// SPOCART — Shared catalogue widgets
//------------------------------------------------------------------------------
// ProductCard   — vertical card for rails / grids (Home "Popular Products").
// ProductRow    — horizontal row for category listings, search and wishlist.
// CategoryTile  — circular icon + label (Home rail and the Categories grid).
// addProductToCart — the one add-to-cart behaviour every surface shares.
//==============================================================================

/// Adds [product] to the cart (at its MOQ on first add) with a snackbar that
/// links to the cart. Used by every "+ Add to Cart" in the app.
///
/// A product sold in sizes must carry one — the server rejects a size-less line
/// at checkout — so when [size] is not given the size sheet opens first.
/// Dismissing that sheet adds nothing.
Future<void> addProductToCart(
  BuildContext context,
  Product product, {
  String? size,
}) async {
  if (!product.inStock) {
    showAppSnackBar(context, '${product.name} is currently out of stock.',
        tone: SnackTone.error);
    return;
  }

  String? chosen = size;
  if (product.sizes.isNotEmpty && chosen == null) {
    chosen = await showSizePickerSheet(context, product);
    if (chosen == null || !context.mounted) return;
  }

  final CartController cart = AppScope.of(context).cart;
  final bool fresh = cart.lineFor(product.id, size: chosen) == null;
  final int qty = cart.add(product, size: chosen);
  final String sizeNote = chosen == null ? '' : ' (size $chosen)';
  showCartSnack(
    context,
    fresh
        ? 'Added ${product.moq} × ${product.name}$sizeNote to cart'
        : '${product.name}$sizeNote — $qty in cart',
  );
}

/// Success snackbar with a "View Cart" action.
void showCartSnack(BuildContext context, String message) {
  showAppSnackBar(
    context,
    message,
    tone: SnackTone.success,
    actionLabel: 'View Cart',
    onAction: () => AppNavigator.backToHome(context, tab: HomeTab.cart),
  );
}

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.width = 150});

  final Product product;
  final double width;

  @override
  Widget build(BuildContext context) {
    final CartController cart = AppScope.of(context).cart;
    return SizedBox(
      width: width,
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: () => AppNavigator.toProduct(context, product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ProductImage(
                  source: product.primaryImage,
                  width: width,
                  height: width * 0.78,
                  radius: 0,
                  fallbackIcon: _iconFor(context, product),
                ),
                if (!product.inStock)
                  const Positioned(
                    top: 8,
                    left: 8,
                    child: StatusPill(
                      label: 'Out of Stock',
                      color: AppColors.textSoft,
                      background: AppColors.surfaceAlt,
                      dense: true,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.smallStrong,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatInr(product.bestPrice)}+',
                    style: AppTypography.price.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ListenableBuilder(
                    listenable: cart,
                    builder: (context, _) => SizedBox(
                      width: double.infinity,
                      child: AddToCartButton(
                        inCartQuantity: cart.quantityOf(product.id),
                        onPressed: () => addProductToCart(context, product),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductRow extends StatelessWidget {
  const ProductRow({
    super.key,
    required this.product,
    this.trailing,
    this.showAddToCart = true,
  });

  final Product product;

  /// Optional top-right control (e.g. a remove ✕ on the wishlist).
  final Widget? trailing;
  final bool showAddToCart;

  @override
  Widget build(BuildContext context) {
    final CartController cart = AppScope.of(context).cart;
    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: () => AppNavigator.toProduct(context, product),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductImage(
            source: product.primaryImage,
            size: 84,
            fallbackIcon: _iconFor(context, product),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.title,
                      ),
                    ),
                    ?trailing,
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatInrRange(product.bestPrice, product.basePrice)} / ${product.unit}',
                  style: AppTypography.small.copyWith(
                    color: AppColors.textSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(child: StockPill(inStock: product.inStock)),
                    const SizedBox(width: AppSpacing.xs),
                    if (showAddToCart)
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: ListenableBuilder(
                            listenable: cart,
                            builder: (context, _) => AddToCartButton(
                              inCartQuantity: cart.quantityOf(product.id),
                              onPressed: () =>
                                  addProductToCart(context, product),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StockPill extends StatelessWidget {
  const StockPill({super.key, required this.inStock});

  final bool inStock;

  @override
  Widget build(BuildContext context) {
    return inStock
        ? const StatusPill(label: 'In Stock', color: AppColors.success)
        : const StatusPill(
            label: 'Out of Stock',
            color: AppColors.textSoft,
            background: AppColors.surfaceAlt,
          );
  }
}

class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.size = 60,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: selected ? AppColors.red : AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.red : AppColors.border,
                ),
              ),
              child: Icon(
                icon,
                size: size * 0.44,
                color: selected ? AppColors.white : AppColors.black,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: size + 24,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(BuildContext context, Product product) =>
    AppScope.of(context).catalog.categoryById(product.categoryId)?.icon ??
    Icons.sports_rounded;

/// Category icon lookup for surfaces that only hold a product.
IconData productFallbackIcon(BuildContext context, Product product) =>
    _iconFor(context, product);

/// Skeleton placeholders while the catalogue loads.
class ProductRowSkeleton extends StatelessWidget {
  const ProductRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.all(10),
      child: Row(
        children: [
          SkeletonBox(width: 84, height: 84, radius: AppRadius.md),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 160, height: 14),
                SizedBox(height: 8),
                SkeletonBox(width: 110, height: 12),
                SizedBox(height: 14),
                SkeletonBox(width: 70, height: 20, radius: AppRadius.pill),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
