import 'package:flutter/material.dart';

import '../../app/app_navigator.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/catalog.dart';
import '../../state/catalog_controller.dart';
import '../catalog/widgets/product_widgets.dart';

//==============================================================================
// SPOCART — Home tab
//------------------------------------------------------------------------------
// Logo bar with notifications + cart, search, hero banner, category rail,
// popular products and the bulk / custom order entry points.
//==============================================================================

class HomeTabView extends StatelessWidget {
  const HomeTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.of(context);
    final CatalogController catalog = services.catalog;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SpocartAppBar(
        showBack: false,
        titleWidget: const BrandLogo(height: 30),
        actions: [
          ListenableBuilder(
            listenable: services.notifications,
            builder: (context, _) => AppIconButton(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Notifications',
              badgeCount: services.notifications.unreadCount,
              onPressed: () => AppNavigator.toNotifications(context),
            ),
          ),
          ListenableBuilder(
            listenable: services.cart,
            builder: (context, _) => AppIconButton(
              icon: Icons.shopping_cart_outlined,
              tooltip: 'Cart',
              badgeCount: services.cart.lineCount,
              onPressed: () =>
                  AppNavigator.backToHome(context, tab: HomeTab.cart),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: catalog,
        builder: (context, _) {
          if (catalog.error != null && !catalog.loaded) {
            return ErrorStateView(
              message: catalog.error,
              onRetry: () => catalog.load(force: true),
            );
          }
          return RefreshIndicator(
            color: AppColors.red,
            onRefresh: () => catalog.load(force: true),
            child: ContentWidth(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page, AppSpacing.xs, AppSpacing.page, 0),
                    child: AppSearchBar(
                      readOnly: true,
                      onTap: () => AppNavigator.toSearch(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Padding(
                    padding: AppSpacing.pagePadding,
                    child: _HeroBanner(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _CategoryRail(catalog: catalog),
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(
                    title: 'Best Sellers',
                    actionLabel: 'View All',
                    onAction: () => AppNavigator.backToHome(
                      context,
                      tab: HomeTab.categories,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _BestSellerRail(catalog: catalog),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionHeader(
                    title: 'Buying in Bulk?',
                    subtitle: 'Upload a list or design a team kit',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Padding(
                    padding: AppSpacing.pagePadding,
                    child: _BulkShortcuts(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.lgAll,
      child: AspectRatio(
        aspectRatio: 2.15,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/football_match.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppColors.black),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xE60B0B0C), Color(0x800B0B0C), Color(0x1A0B0B0C)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Bulk Sports\nProducts for\nYour Business',
                    style: AppTypography.h2.copyWith(
                      color: AppColors.white,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PrimaryButton(
                    label: 'Shop Now',
                    size: ButtonSize.small,
                    expand: false,
                    onPressed: () => AppNavigator.backToHome(
                      context,
                      tab: HomeTab.categories,
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

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({required this.catalog});

  final CatalogController catalog;

  @override
  Widget build(BuildContext context) {
    if (!catalog.loaded) {
      return SizedBox(
        height: 112,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: AppSpacing.pagePadding,
          itemCount: 5,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (_, _) => const Column(
            children: [
              SkeletonBox(width: 60, height: 60, radius: 30),
              SizedBox(height: 8),
              SkeletonBox(width: 48, height: 10),
            ],
          ),
        ),
      );
    }

    final List<ProductCategory> featured = catalog.categories.take(4).toList();
    return SizedBox(
      height: 112,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        children: [
          for (final ProductCategory c in featured)
            CategoryTile(
              label: c.name,
              icon: c.icon,
              onTap: () => AppNavigator.toCategory(context, c),
            ),
          CategoryTile(
            label: 'More',
            icon: Icons.apps_rounded,
            onTap: () =>
                AppNavigator.backToHome(context, tab: HomeTab.categories),
          ),
        ],
      ),
    );
  }
}

class _BestSellerRail extends StatelessWidget {
  const _BestSellerRail({required this.catalog});

  final CatalogController catalog;

  @override
  Widget build(BuildContext context) {
    const double cardWidth = 150;
    const double railHeight = 236;

    if (!catalog.loaded) {
      return SizedBox(
        height: railHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: AppSpacing.pagePadding,
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (_, _) => const SkeletonBox(
            width: cardWidth,
            height: railHeight,
            radius: AppRadius.lg,
          ),
        ),
      );
    }

    // Ranked by what actually sold in the last 30 days, with anything an admin
    // pinned in front; falls back to the catalogue's popular flag on a store
    // that has not sold anything yet.
    final List<Product> best = catalog.bestSellers;
    if (best.isEmpty) {
      return const Padding(
        padding: AppSpacing.pagePadding,
        child: EmptyStateView(
          icon: Icons.storefront_outlined,
          title: 'No best sellers yet',
          message: 'Products will appear here as orders come in.',
          compact: true,
        ),
      );
    }

    return SizedBox(
      height: railHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.pagePadding,
        itemCount: best.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) =>
            ProductCard(product: best[i], width: cardWidth),
      ),
    );
  }
}

class _BulkShortcuts extends StatelessWidget {
  const _BulkShortcuts();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ShortcutCard(
            icon: Icons.upload_file_outlined,
            title: 'Bulk Order Upload',
            subtitle: 'CSV or manual list',
            onTap: () => AppNavigator.toBulkUpload(context),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ShortcutCard(
            icon: Icons.checkroom_outlined,
            title: 'Custom Team Kits',
            subtitle: 'Jerseys & printing',
            onTap: () => AppNavigator.toCustomOrder(context),
          ),
        ),
      ],
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: AppColors.black,
      borderColor: AppColors.black,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.red, size: 26),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.title.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textOnDarkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
