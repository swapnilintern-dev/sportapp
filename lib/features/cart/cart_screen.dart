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
import '../../core/widgets/state_views.dart';
import '../../data/models/catalog.dart';
import '../../data/models/order.dart';
import '../../state/cart_controller.dart';
import '../catalog/widgets/product_widgets.dart';
import '../support/help_sheet.dart';

//==============================================================================
// SPOCART — Cart
//------------------------------------------------------------------------------
// Line items with steppers, GST summary and Proceed to Checkout. "Need Help?"
// (app bar) and the floating chat button open the support sheet. Checkout
// requires business details — the registration screen is offered first for
// unregistered buyers and can be skipped.
//==============================================================================

class CartScreen extends StatelessWidget {
  const CartScreen({super.key, this.isTab = false});

  final bool isTab;

  Future<void> _clearAll(BuildContext context, CartController cart) async {
    final bool ok = await showAppConfirmDialog(
      context,
      title: 'Clear cart?',
      message: 'All ${cart.lineCount} items will be removed from your cart.',
      confirmLabel: 'Clear All',
      destructive: true,
      icon: Icons.remove_shopping_cart_outlined,
    );
    if (ok) cart.clear();
  }

  Future<void> _checkout(BuildContext context) async {
    final AppServices services = AppScope.of(context);
    final CartController cart = services.cart;

    final List<CartLine> short = cart.belowMoq;
    if (short.isNotEmpty) {
      final Product? p = cart.productOf(short.first);
      showAppSnackBar(
        context,
        '${p?.name ?? 'An item'} is below its minimum order of ${p?.moq ?? 1}.',
        tone: SnackTone.error,
      );
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (!services.session.isRegistered) {
      await AppNavigator.toBusinessRegistration(context);
      if (!context.mounted) return;
    }
    await AppNavigator.toCheckout(context);
  }

  @override
  Widget build(BuildContext context) {
    final CartController cart = AppScope.of(context).cart;
    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) {
        final bool empty = cart.isEmpty;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: SpocartAppBar(
            title: empty ? 'My Cart' : 'My Cart (${cart.lineCount})',
            showBack: !isTab,
            actions: [
              if (!empty)
                GhostButton(
                  label: 'Clear All',
                  onPressed: () => _clearAll(context, cart),
                ),
              GhostButton(
                label: 'Need Help?',
                color: AppColors.textSoft,
                onPressed: () => showHelpSheet(context),
              ),
            ],
          ),
          body: empty
              ? EmptyStateView(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Your cart is empty',
                  message:
                      'Browse the catalogue and add products at their bulk minimums.',
                  actionLabel: 'Browse Products',
                  onAction: () => AppNavigator.backToHome(
                    context,
                    tab: HomeTab.categories,
                  ),
                )
              : ContentWidth(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page, AppSpacing.xs, AppSpacing.page, 96),
                    itemCount: cart.lines.length + 1,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      if (i == cart.lines.length) {
                        return _Summary(cart: cart);
                      }
                      return _CartLineTile(line: cart.lines[i], cart: cart);
                    },
                  ),
                ),
          floatingActionButton: empty
              ? null
              : FloatingActionButton(
                  onPressed: () => showHelpSheet(context),
                  backgroundColor: AppColors.red,
                  foregroundColor: AppColors.white,
                  tooltip: 'Need help?',
                  child: const Icon(Icons.chat_bubble_outline_rounded),
                ),
          bottomNavigationBar: empty
              ? null
              : BottomActionBar(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Total (incl. GST)',
                                style: AppTypography.caption),
                            Text(formatInr(cart.total),
                                style: AppTypography.h2),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: PrimaryButton(
                          label: 'Proceed to Checkout',
                          onPressed: () => _checkout(context),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({required this.line, required this.cart});

  final CartLine line;
  final CartController cart;

  @override
  Widget build(BuildContext context) {
    final Product? product = cart.productOf(line);
    if (product == null) {
      return AppCard(
        color: AppColors.surface,
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text('This product is no longer available.',
                  style: AppTypography.small),
            ),
            GhostButton(label: 'Remove', onPressed: () => cart.remove(line)),
          ],
        ),
      );
    }

    final double unitPrice = cart.unitPrice(line);
    final bool belowMoq = line.quantity < product.moq;

    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => AppNavigator.toProduct(context, product),
            child: ProductImage(
              source: product.primaryImage,
              size: 72,
              fallbackIcon: productFallbackIcon(context, product),
            ),
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
                    AppIconButton(
                      icon: Icons.delete_outline_rounded,
                      tooltip: 'Remove',
                      size: 32,
                      iconSize: 19,
                      color: AppColors.textMuted,
                      onPressed: () => cart.remove(line),
                    ),
                  ],
                ),
                Text(
                  '${formatInr(unitPrice)} / ${product.unit}'
                  '${line.size != null ? '  ·  Size ${line.size}' : ''}',
                  style: AppTypography.small,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    QuantityStepper(
                      value: line.quantity,
                      min: 1,
                      compact: true,
                      onChanged: (v) => cart.setQuantity(line, v),
                    ),
                    const Spacer(),
                    Text(formatInr(cart.lineTotal(line)),
                        style: AppTypography.bodyStrong),
                  ],
                ),
                if (belowMoq)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Minimum order is ${product.moq} ${product.unit}',
                      style: AppTypography.caption.copyWith(color: AppColors.red),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.cart});

  final CartController cart;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surface,
      borderColor: AppColors.surface,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          SummaryRow(label: 'Subtotal', value: formatInr(cart.subtotal)),
          SummaryRow(
            label: 'GST (${(CartController.gstRate * 100).round()}%)',
            value: formatInr(cart.gst),
          ),
          const Divider(height: AppSpacing.md),
          SummaryRow(
            label: 'Total',
            value: formatInr(cart.total),
            emphasized: true,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${cart.totalUnits} units across ${cart.lineCount} product${cart.lineCount == 1 ? '' : 's'} · GST invoice included',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}
