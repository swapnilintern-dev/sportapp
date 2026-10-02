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
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../data/repositories/repositories.dart';
import 'barcode_scan_screen.dart';
import 'product_list_screen.dart';
import 'widgets/product_widgets.dart';
import 'widgets/voice_search.dart';

//==============================================================================
// SPOCART — Search
//------------------------------------------------------------------------------
// Ranked search over name / brand / sub-category that understands the trade's
// vocabulary and forgives a typo, with popular suggestions and category
// shortcuts before a query is typed. The mic dictates a search on the phone's
// own engine; the scanner reads a carton's barcode and the server resolves it.
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

  bool _scanning = false;

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
        actions: <Widget>[
          AppIconButton(
            icon: Icons.mic_none_rounded,
            tooltip: 'Search by voice',
            onPressed: _listen,
          ),
          AppIconButton(
            icon: Icons.qr_code_scanner_rounded,
            tooltip: 'Scan a barcode',
            onPressed: _scan,
          ),
        ],
      ),
      body: _scanning
          ? const AppLoader()
          : KeyboardDismisser(
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
                    final bool corrected = catalog.searchWasCorrected(q);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${results.length} result${results.length == 1 ? '' : 's'}',
                          style: AppTypography.small,
                        ),
                        if (corrected)
                          Text(
                            'No exact match for "$q" — showing the closest products.',
                            style: AppTypography.caption
                                .copyWith(color: AppColors.textSoft),
                          ),
                      ],
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

  /// Dictation goes into the ordinary search; nothing bypasses it.
  Future<void> _listen() async {
    final String? spoken = await showVoiceSearchSheet(context);
    if (spoken == null || !mounted) return;
    setState(() => _query.text = spoken);
  }

  /// A scanned code is resolved by the server. An unknown code is reported, not
  /// guessed at, and the code is left in the box so it can be searched by hand.
  Future<void> _scan() async {
    final String? code = await scanProductBarcode(context);
    if (code == null || !mounted) return;

    setState(() => _scanning = true);
    try {
      final Product product =
          await AppScope.of(context).catalog.productByBarcode(code);
      if (!mounted) return;
      await AppNavigator.toProduct(context, product);
    } on AppException catch (e) {
      if (mounted) {
        setState(() => _query.text = code);
        showAppSnackBar(context, e.message, tone: SnackTone.error);
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not look up that barcode.',
            tone: SnackTone.error);
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
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
