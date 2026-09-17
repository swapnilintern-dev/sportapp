import 'package:flutter/material.dart';

import '../../app/app_navigator.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/catalog.dart';
import '../../state/catalog_controller.dart';
import 'product_list_screen.dart';
import 'widgets/product_widgets.dart';

//==============================================================================
// SPOCART — Search
//------------------------------------------------------------------------------
// Live search over name / brand / sub-category with popular suggestions and
// category shortcuts before a query is typed.
//==============================================================================

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _query =
      TextEditingController(text: widget.initialQuery ?? '');

  static const List<String> _suggestions = <String>[
    'Cricket bat',
    'Football',
    'Badminton racket',
    'Jersey',
    'Dumbbell',
    'Shuttlecock',
    'Helmet',
  ];

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CatalogController catalog = AppScope.of(context).catalog;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SpocartAppBar(
        titleWidget: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: AppSearchBar(
            controller: _query,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            onClear: () => setState(_query.clear),
          ),
        ),
      ),
      body: KeyboardDismisser(
        child: ListenableBuilder(
          listenable: catalog,
          builder: (context, _) {
            if (!catalog.loaded) {
              return catalog.error != null
                  ? ErrorStateView(
                      message: catalog.error,
                      onRetry: () => catalog.load(force: true),
                    )
                  : const AppLoader();
            }
            final String q = _query.text.trim();
            if (q.isEmpty) return _Suggestions(onPick: _apply, catalog: catalog);
            final List<Product> results = catalog.search(q);
            if (results.isEmpty) {
              return EmptyStateView(
                icon: Icons.search_off_rounded,
                title: 'No results for "$q"',
                message:
                    'Check the spelling or try a broader term like "ball" or "racket".',
                actionLabel: 'Browse Categories',
                onAction: () => AppNavigator.backToHome(
                  context,
                  tab: HomeTab.categories,
                ),
              );
            }
            return ContentWidth(
              child: ListView.separated(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(AppSpacing.page),
                itemCount: results.length + 1,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Text(
                      '${results.length} result${results.length == 1 ? '' : 's'}',
                      style: AppTypography.small,
                    );
                  }
                  return ProductRow(product: results[i - 1]);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _apply(String term) {
    _query.text = term;
    _query.selection = TextSelection.collapsed(offset: term.length);
    setState(() {});
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onPick, required this.catalog});

  final ValueChanged<String> onPick;
  final CatalogController catalog;

  @override
  Widget build(BuildContext context) {
    return ContentWidth(
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          const Text('Popular searches', style: AppTypography.overline),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final String s in _SearchScreenState._suggestions)
                FilterChipPill(
                  label: s,
                  selected: false,
                  onTap: () => onPick(s),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text('Browse by sport', style: AppTypography.overline),
          const SizedBox(height: AppSpacing.xs),
          for (final ProductCategory c in catalog.categories)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(c.icon, size: 20, color: AppColors.black),
              ),
              title: Text(c.name, style: AppTypography.title),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted),
              onTap: () => AppNavigator.toCategory(context, c),
            ),
        ],
      ),
    );
  }
}
