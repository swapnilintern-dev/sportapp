import 'package:flutter/material.dart';

import '../../app/app_navigator.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/catalog.dart';
import '../../state/analytics_controller.dart';
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
  bool _assisting = false;
  AssistResult? _assist;
  String _assistedQuery = '';

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
            onChanged: (_) => setState(() => _assist = null),
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
            if (_assisting) return const AppLoader();
            if (_assist != null) {
              return _AssistResults(
                result: _assist!,
                query: _assistedQuery,
                onClear: () => setState(() => _assist = null),
              );
            }
            final List<Product> results = catalog.search(q);
            _reportSearch(q, results.length);
            if (results.isEmpty) {
              return EmptyStateView(
                icon: Icons.search_off_rounded,
                title: 'No results for "$q"',
                message:
                    'Check the spelling or try a broader term like "ball" or "racket".',
                actionLabel: 'Ask SPOCART',
                onAction: () => _ask(q),
                secondaryActionLabel: 'Browse Categories',
                onSecondaryAction: () => AppNavigator.backToHome(
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
                itemCount: results.length + 2,
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
                  if (i == results.length + 1) {
                    return _AskSpocartTile(
                      query: q,
                      onAsk: () => _ask(q),
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

  /// Describes what is needed in plain words and lets the server suggest. The
  /// products that come back are always real catalogue entries — the server
  /// drops anything its assistant invents — so this screen just shows them.
  Future<void> _ask(String query) async {
    if (_assisting) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _assisting = true;
      _assistedQuery = query;
    });
    try {
      final AssistResult result =
          await AppScope.of(context).catalog.assist(query);
      if (mounted) setState(() => _assist = result);
    } on AppException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, tone: SnackTone.error);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not ask right now. Please try again.',
            tone: SnackTone.error);
      }
    } finally {
      if (mounted) setState(() => _assisting = false);
    }
  }

  String _reportedQuery = '';

  /// Reports that a search happened, with how many products it found and how
  /// long the query was — never the query itself. Debounced on the text so a
  /// buyer typing one word is one event, not eight.
  void _reportSearch(String query, int results) {
    if (query == _reportedQuery) return;
    _reportedQuery = query;
    AppScope.of(context).analytics.log(
          AppEvent.search,
          results: results,
          queryLength: query.length,
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
          if (catalog.popularSearches().isNotEmpty) ...[
            const Text('Popular searches', style: AppTypography.overline),
            const SizedBox(height: AppSpacing.sm),
          ],
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              // Drawn from what is actually selling and what the catalogue
              // stocks, never a hand-written list of product names.
              for (final String s in catalog.popularSearches())
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

/// Offered under the results: plain matching found some products, but a buyer
/// describing a whole requirement may want a suggested set instead.
class _AskSpocartTile extends StatelessWidget {
  const _AskSpocartTile({required this.query, required this.onAsk});

  final String query;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: AppCard(
        color: AppColors.surface,
        borderColor: AppColors.surface,
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: onAsk,
        child: Row(
          children: <Widget>[
            const Icon(Icons.auto_awesome_outlined, color: AppColors.red),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Not quite it?', style: AppTypography.bodyStrong),
                  Text(
                    'Describe what you need and we will suggest a set.',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// What the server suggested. Every product here is a real catalogue entry; the
/// server drops anything its assistant invents, so this screen only displays.
class _AssistResults extends StatelessWidget {
  const _AssistResults({
    required this.result,
    required this.query,
    required this.onClear,
  });

  final AssistResult result;
  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (result.products.isEmpty) {
      return EmptyStateView(
        icon: Icons.inventory_2_outlined,
        title: 'Nothing matched that',
        message: result.answer.isNotEmpty
            ? result.answer
            : 'Tell us what you need and we will source it for you.',
        actionLabel: 'Request a Quote',
        onAction: () => AppNavigator.toCustomOrder(context),
        secondaryActionLabel: 'Back to search',
        onSecondaryAction: onClear,
      );
    }

    return ContentWidth(
      child: ListView.separated(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(AppSpacing.page),
        itemCount: result.products.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Suggested for "$query"',
                        style: AppTypography.bodyStrong,
                      ),
                    ),
                    GhostButton(label: 'Clear', onPressed: onClear),
                  ],
                ),
                if (result.answer.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(result.answer, style: AppTypography.small),
                ],
                // Said plainly, so nobody mistakes a suggestion for a quote.
                const SizedBox(height: 2),
                Text(
                  result.fromAssistant
                      ? 'Suggestions from SPOCART. Prices and stock are always ours.'
                      : 'Closest products in the catalogue.',
                  style: AppTypography.caption.copyWith(color: AppColors.textSoft),
                ),
              ],
            );
          }
          return ProductRow(product: result.products[i - 1]);
        },
      ),
    );
  }
}
