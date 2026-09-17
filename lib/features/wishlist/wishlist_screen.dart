import 'package:flutter/material.dart';

import '../../app/app_navigator.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/catalog.dart';
import '../../state/cart_controller.dart';
import '../catalog/widgets/product_widgets.dart';

//==============================================================================
// SPOCART — Wishlist
//------------------------------------------------------------------------------
// Saved products with add-to-cart and remove. Clear All confirms first.
//==============================================================================

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.of(context);
    final WishlistController wishlist = services.wishlist;

    return ListenableBuilder(
      listenable: Listenable.merge([wishlist, services.catalog]),
      builder: (context, _) {
        final List<Product> products = wishlist.ids
            .map(services.catalog.productById)
            .whereType<Product>()
            .toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: SpocartAppBar(
            title: 'Wishlist',
            actions: [
              if (products.isNotEmpty)
                GhostButton(
                  label: 'Clear All',
                  onPressed: () async {
                    final bool ok = await showAppConfirmDialog(
                      context,
                      title: 'Clear wishlist?',
                      message: 'All saved products will be removed.',
                      confirmLabel: 'Clear All',
                      destructive: true,
                      icon: Icons.favorite_border_rounded,
                    );
                    if (ok) wishlist.clear();
                  },
                ),
            ],
          ),
          body: !services.catalog.loaded
              ? const AppLoader()
              : products.isEmpty
                  ? EmptyStateView(
                      icon: Icons.favorite_border_rounded,
                      title: 'Nothing saved yet',
                      message:
                          'Tap the heart on any product to keep it here for your next order.',
                      actionLabel: 'Browse Products',
                      onAction: () => AppNavigator.backToHome(
                        context,
                        tab: HomeTab.categories,
                      ),
                    )
                  : ContentWidth(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.page),
                        itemCount: products.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, i) => ProductRow(
                          product: products[i],
                          trailing: AppIconButton(
                            icon: Icons.close_rounded,
                            tooltip: 'Remove',
                            size: 30,
                            iconSize: 18,
                            color: AppColors.textMuted,
                            onPressed: () {
                              wishlist.remove(products[i].id);
                              showAppSnackBar(
                                context,
                                'Removed from wishlist',
                                actionLabel: 'Undo',
                                onAction: () => wishlist.toggle(products[i].id),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
        );
      },
    );
  }
}
