import 'package:flutter/material.dart';

import '../../app/app_navigator.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/catalog.dart';
import '../../state/catalog_controller.dart';
import 'widgets/product_widgets.dart';

//==============================================================================
// SPOCART — Category / product listing
//------------------------------------------------------------------------------
// Sub-category chips (All, Bats, Balls…), a sort control and the product
// rows with stock + add-to-cart.
//==============================================================================

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key, required this.category});

  final ProductCategory category;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  String? _subcategory;
  ProductSort _sort = ProductSort.relevance;

  Future<void> _pickSort() async {
    final ProductSort? picked = await showAppBottomSheet<ProductSort>(
      context,
      title: 'Sort by',
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs, 0, AppSpacing.xs, AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final ProductSort s in ProductSort.values)
              ListTile(
                onTap: () => Navigator.of(context).pop(s),
                title: Text(
                  s.label,
                  style: s == _sort
                      ? AppTypography.bodyStrong
                      : AppTypography.body,
                ),
                trailing: s == _sort
                    ? const Icon(Icons.check_rounded, color: AppColors.red)
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _sort = picked);
  }

  @override
  Widget build(BuildContext context) {
    final CatalogController catalog = AppScope.of(context).catalog;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SpocartAppBar(
        title: widget.category.name,
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
          final List<Product> products = sortProducts(
            catalog.inCategory(widget.category.id, subcategory: _subcategory),
            _sort,
          );
          return ContentWidth(
            child: Column(
              children: [
                _FilterBar(
                  subcategories: widget.category.subcategories,
                  selected: _subcategory,
                  onSelected: (s) => setState(() => _subcategory = s),
                  sortLabel: _sort == ProductSort.relevance
                      ? 'Sort'
                      : _sort.label,
                  onSort: _pickSort,
                ),
                Expanded(
                  child: !catalog.loaded
                      ? ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.page),
                          itemCount: 5,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (_, _) => const ProductRowSkeleton(),
                        )
                      : products.isEmpty
                          ? EmptyStateView(
                              icon: Icons.inventory_2_outlined,
                              title: 'No products here yet',
                              message: _subcategory == null
                                  ? 'We are adding ${widget.category.name} products soon. Ask us for a quote in the meantime.'
                                  : 'Nothing under "$_subcategory" right now. Try another filter.',
                              actionLabel: _subcategory == null
                                  ? 'Request a Quote'
                                  : 'Show All',
                              onAction: _subcategory == null
                                  ? () => AppNavigator.toCustomOrder(context)
                                  : () => setState(() => _subcategory = null),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.page,
                                  AppSpacing.xs,
                                  AppSpacing.page,
                                  AppSpacing.xl),
                              itemCount: products.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, i) =>
                                  ProductRow(product: products[i]),
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.subcategories,
    required this.selected,
    required this.onSelected,
    required this.sortLabel,
    required this.onSort,
  });

  final List<String> subcategories;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final String sortLabel;
  final VoidCallback onSort;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.page, vertical: 8),
            children: [
              FilterChipPill(
                label: 'All',
                selected: selected == null,
                onTap: () => onSelected(null),
              ),
              for (final String s in subcategories) ...[
                const SizedBox(width: AppSpacing.xs),
                FilterChipPill(
                  label: s,
                  selected: selected == s,
                  onTap: () => onSelected(selected == s ? null : s),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.xs, 0),
          child: Row(
            children: [
              const Spacer(),
              TextButton.icon(
                onPressed: onSort,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.text,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.swap_vert_rounded, size: 18),
                label: Text(sortLabel, style: AppTypography.smallStrong),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Red-filled when selected, outlined otherwise — the listing filter chip.
class FilterChipPill extends StatelessWidget {
  const FilterChipPill({
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
      color: selected ? AppColors.red : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.pillAll,
        side: BorderSide(color: selected ? AppColors.red : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
