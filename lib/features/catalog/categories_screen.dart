import 'package:flutter/material.dart';

import '../../app/app_navigator.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/catalog.dart';
import '../../state/catalog_controller.dart';

//==============================================================================
// SPOCART — All Categories
//------------------------------------------------------------------------------
// Three-column grid of every sport. Tapping opens the category listing.
//==============================================================================

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key, this.isTab = false});

  final bool isTab;

  @override
  Widget build(BuildContext context) {
    final CatalogController catalog = AppScope.of(context).catalog;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SpocartAppBar(
        title: 'Categories',
        showBack: !isTab,
        actions: [
          AppIconButton(
            icon: Icons.search_rounded,
            tooltip: 'Search',
            onPressed: () => AppNavigator.toSearch(context),
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
          if (!catalog.loaded) {
            return _CategoryGrid(
              itemCount: 9,
              itemBuilder: (_, _) => const _CategorySkeleton(),
            );
          }
          final List<ProductCategory> categories = catalog.categories;
          if (categories.isEmpty) {
            return EmptyStateView(
              icon: Icons.category_outlined,
              title: 'No categories available',
              message: 'Pull to refresh or try again shortly.',
              actionLabel: 'Refresh',
              onAction: () => catalog.load(force: true),
            );
          }
          return RefreshIndicator(
            color: AppColors.red,
            onRefresh: () => catalog.load(force: true),
            child: _CategoryGrid(
              itemCount: categories.length,
              itemBuilder: (context, i) => _CategoryCell(
                category: categories[i],
                productCount: catalog.inCategory(categories[i].id).length,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.itemCount, required this.itemBuilder});

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return ContentWidth(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final int columns = constraints.maxWidth >= 480 ? 4 : 3;
          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.xl),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.8,
            ),
            itemCount: itemCount,
            itemBuilder: itemBuilder,
          );
        },
      ),
    );
  }
}

class _CategoryCell extends StatelessWidget {
  const _CategoryCell({required this.category, required this.productCount});

  final ProductCategory category;
  final int productCount;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      onTap: () => AppNavigator.toCategory(context, category),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(category.icon, size: 26, color: AppColors.black),
          ),
          const SizedBox(height: 10),
          Text(
            category.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.smallStrong.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            productCount == 1 ? '1 product' : '$productCount products',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

class _CategorySkeleton extends StatelessWidget {
  const _CategorySkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SkeletonBox(width: 52, height: 52, radius: 26),
          SizedBox(height: 10),
          SkeletonBox(width: 56, height: 11),
        ],
      ),
    );
  }
}
