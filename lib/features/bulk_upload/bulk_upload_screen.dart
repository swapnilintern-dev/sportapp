import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_navigator.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../data/models/catalog.dart';
import '../../data/models/engagement.dart';
import '../../state/cart_controller.dart';
import '../../state/catalog_controller.dart';
import '../catalog/widgets/product_widgets.dart';
import '../quotes/request_quote_sheet.dart';
import '../support/help_sheet.dart';
import 'bulk_parser.dart';

//==============================================================================
// SPOCART — Bulk Order Upload
//------------------------------------------------------------------------------
// Upload File: pick a CSV, match rows to the catalogue, review, add to cart.
// Enter Manually: build the same list row by row. Unmatched rows can be sent
// as a quote request so nothing the buyer typed is lost.
//==============================================================================

class BulkUploadScreen extends StatefulWidget {
  const BulkUploadScreen({super.key});

  @override
  State<BulkUploadScreen> createState() => _BulkUploadScreenState();
}

class _BulkUploadScreenState extends State<BulkUploadScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final List<ManualRow> _manual = <ManualRow>[ManualRow()];
  List<BulkRow> _parsed = <BulkRow>[];
  String? _fileName;
  bool _reviewing = false;
  bool _parsing = false;

  CatalogController get _catalog => AppScope.of(context).catalog;

  @override
  void initState() {
    super.initState();
    _catalog.load();
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final ManualRow r in _manual) {
      r.dispose();
    }
    super.dispose();
  }

  //----------------------------------------------------------------------------
  // Upload tab
  //----------------------------------------------------------------------------
  Future<void> _pickCsv() async {
    setState(() => _parsing = true);
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'txt'],
      );
      if (file == null) return;
      final Uint8List bytes = await file.readAsBytes();
      await _catalog.load();
      final String text = utf8.decode(bytes, allowMalformed: true);
      final List<BulkRow> rows = parseBulkCsv(text, _catalog);
      if (!mounted) return;
      if (rows.isEmpty) {
        showAppSnackBar(
          context,
          'No rows found. Use the sample template: product, quantity, size.',
          tone: SnackTone.error,
        );
        return;
      }
      setState(() {
        _parsed = rows;
        _fileName = file.name;
      });
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not open the file picker.',
            tone: SnackTone.error);
      }
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  Future<void> _showTemplate() async {
    await showAppBottomSheet<void>(
      context,
      title: 'Sample Template',
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Save your sheet as CSV with these three columns. Product can be our product ID or the product name; size is optional.',
              style: AppTypography.bodyMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                kBulkCsvTemplate,
                style: AppTypography.small.copyWith(
                  fontFamily: 'monospace',
                  fontFamilyFallback: const ['Menlo', 'Courier'],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Copy Template',
              icon: Icons.copy_rounded,
              onPressed: () async {
                await Clipboard.setData(
                    const ClipboardData(text: kBulkCsvTemplate));
                if (context.mounted) {
                  Navigator.of(context).pop();
                  showAppSnackBar(context,
                      'Template copied — paste it into a new sheet and export as CSV.',
                      tone: SnackTone.success);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  //----------------------------------------------------------------------------
  // Manual tab
  //----------------------------------------------------------------------------
  Future<void> _pickProduct(ManualRow row) async {
    await _catalog.load();
    if (!mounted) return;
    final Product? picked = await showAppBottomSheet<Product>(
      context,
      title: 'Choose Product',
      builder: (context) => _ProductPickerSheet(catalog: _catalog),
    );
    if (picked != null && mounted) {
      setState(() {
        row.product = picked;
        row.size = null;
        if ((int.tryParse(row.qty.text) ?? 0) < picked.moq) {
          row.qty.text = '${picked.moq}';
        }
      });
    }
  }

  void _addRow() => setState(() => _manual.add(ManualRow()));

  void _removeRow(ManualRow row) {
    if (_manual.length == 1) {
      setState(() {
        row.product = null;
        row.qty.clear();
      });
      return;
    }
    setState(() => _manual.remove(row));
    row.dispose();
  }

  //----------------------------------------------------------------------------
  // Review + submit
  //----------------------------------------------------------------------------
  List<BulkRow> get _reviewRows => _tabs.index == 0
      ? _parsed
      : _manual
          .where((r) => r.product != null)
          .map((r) => BulkRow(
                input: r.product!.name,
                product: r.product,
                quantity: int.tryParse(r.qty.text) ?? r.product!.moq,
                size: r.size,
              ))
          .toList();

  void _next() {
    final List<BulkRow> rows = _reviewRows;
    if (rows.isEmpty) {
      showAppSnackBar(
        context,
        _tabs.index == 0
            ? 'Upload a CSV file first.'
            : 'Add at least one product.',
        tone: SnackTone.error,
      );
      return;
    }
    if (_tabs.index == 1) {
      for (final ManualRow r in _manual.where((r) => r.product != null)) {
        final int q = int.tryParse(r.qty.text) ?? 0;
        if (q < r.product!.moq) {
          showAppSnackBar(
            context,
            '${r.product!.name}: minimum order is ${r.product!.moq}.',
            tone: SnackTone.error,
          );
          return;
        }
      }
    }
    setState(() => _reviewing = true);
  }

  void _addMatchedToCart() {
    final CartController cart = AppScope.of(context).cart;
    int added = 0;
    for (final BulkRow row in _reviewRows) {
      final Product? p = row.product;
      if (p == null) continue;
      final int qty = row.quantity < p.moq ? p.moq : row.quantity;
      final line = cart.lineFor(p.id, size: row.size);
      if (line == null) {
        cart.add(p, qty: qty, size: row.size);
      } else {
        cart.setQuantity(line, line.quantity + qty);
      }
      added++;
    }
    showCartSnack(context, '$added product${added == 1 ? '' : 's'} added to cart');
    AppNavigator.backToHome(context, tab: HomeTab.cart);
  }

  Future<void> _quoteUnmatched() async {
    final List<BulkRow> unmatched =
        _reviewRows.where((r) => r.product == null).toList();
    if (unmatched.isEmpty) return;
    try {
      final QuoteRequest quote = await AppScope.of(context).quotes.submit(
        kind: QuoteKind.csv,
        items: [
          for (final BulkRow r in unmatched)
            QuoteItem(description: r.input, quantity: r.quantity, size: r.size),
        ],
        notes: 'Items from bulk upload${_fileName == null ? '' : ' ($_fileName)'} not found in the catalogue.',
      );
      if (mounted) confirmQuoteSubmitted(context, quote);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not submit the quote request.',
            tone: SnackTone.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_reviewing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _reviewing = false);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: SpocartAppBar(
          title: _reviewing ? 'Review Order' : 'Bulk Order Upload',
          onBack: _reviewing
              ? () => setState(() => _reviewing = false)
              : null,
          bottom: _reviewing
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(
                        AppSpacing.page, 0, AppSpacing.page, AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: TabBar(
                      controller: _tabs,
                      indicator: BoxDecoration(
                        color: AppColors.red,
                        borderRadius: AppRadius.mdAll,
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorPadding: const EdgeInsets.all(4),
                      labelColor: AppColors.white,
                      unselectedLabelColor: AppColors.textSoft,
                      overlayColor:
                          const WidgetStatePropertyAll(Colors.transparent),
                      tabs: const [
                        Tab(text: 'Upload File'),
                        Tab(text: 'Enter Manually'),
                      ],
                    ),
                  ),
                ),
        ),
        body: _reviewing
            ? _ReviewList(rows: _reviewRows)
            : KeyboardDismisser(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _UploadTab(
                      fileName: _fileName,
                      rows: _parsed,
                      parsing: _parsing,
                      onPick: _pickCsv,
                      onTemplate: _showTemplate,
                      onClear: () => setState(() {
                        _parsed = <BulkRow>[];
                        _fileName = null;
                      }),
                    ),
                    _ManualTab(
                      rows: _manual,
                      onPickProduct: _pickProduct,
                      onAdd: _addRow,
                      onRemove: _removeRow,
                      onChanged: () => setState(() {}),
                    ),
                  ],
                ),
              ),
        bottomNavigationBar: BottomActionBar(
          child: _reviewing
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PrimaryButton(
                      label: 'Add ${_reviewRows.where((r) => r.product != null).length} Products to Cart',
                      onPressed: _reviewRows.any((r) => r.product != null)
                          ? _addMatchedToCart
                          : null,
                    ),
                    if (_reviewRows.any((r) => r.product == null)) ...[
                      const SizedBox(height: AppSpacing.xs),
                      SecondaryButton(
                        label: 'Request Quote for Unmatched Items',
                        onPressed: _quoteUnmatched,
                      ),
                    ],
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PrimaryButton(label: 'Next', onPressed: _next),
                    const SizedBox(height: 2),
                    GhostButton(
                      label: 'Need help?',
                      color: AppColors.textSoft,
                      onPressed: () => showHelpSheet(context,
                          title: 'Help with bulk orders'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

//------------------------------------------------------------------------------
// Upload tab
//------------------------------------------------------------------------------
class _UploadTab extends StatelessWidget {
  const _UploadTab({
    required this.fileName,
    required this.rows,
    required this.parsing,
    required this.onPick,
    required this.onTemplate,
    required this.onClear,
  });

  final String? fileName;
  final List<BulkRow> rows;
  final bool parsing;
  final VoidCallback onPick;
  final VoidCallback onTemplate;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final int matched = rows.where((r) => r.product != null).length;
    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          InkWell(
            onTap: parsing ? null : onPick,
            borderRadius: AppRadius.lgAll,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.xxl, horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.lgAll,
                border: Border.all(color: AppColors.red, width: 1.2),
              ),
              child: Column(
                children: [
                  if (parsing)
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  else
                    const Icon(Icons.cloud_upload_outlined,
                        size: 48, color: AppColors.red),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    fileName ?? 'Upload Excel / CSV',
                    textAlign: TextAlign.center,
                    style: AppTypography.h3,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fileName == null
                        ? 'Upload product list with quantity\n(export your Excel sheet as CSV)'
                        : '${rows.length} rows · $matched matched to catalogue',
                    textAlign: TextAlign.center,
                    style: AppTypography.small,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  GhostButton(
                    label: fileName == null
                        ? 'Download Sample Template'
                        : 'Choose another file',
                    icon: fileName == null
                        ? Icons.download_outlined
                        : Icons.swap_horiz_rounded,
                    onPressed: fileName == null ? onTemplate : onPick,
                  ),
                ],
              ),
            ),
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                const Expanded(
                  child: Text('Parsed rows', style: AppTypography.h3),
                ),
                GhostButton(
                  label: 'Clear',
                  color: AppColors.textSoft,
                  onPressed: onClear,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final BulkRow r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: BulkRowTile(row: r),
              ),
          ] else ...[
            const SizedBox(height: AppSpacing.lg),
            const Text('How it works', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.xs),
            const _HowStep(1, 'Copy the sample template into your sheet.'),
            const _HowStep(2, 'Fill product name or ID, quantity and size.'),
            const _HowStep(3, 'Export as CSV and upload it here.'),
            const _HowStep(4, 'Review matches, then add everything to cart.'),
          ],
        ],
      ),
    );
  }
}

class _HowStep extends StatelessWidget {
  const _HowStep(this.n, this.text);

  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: AppColors.black,
            child: Text('$n',
                style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTypography.body)),
        ],
      ),
    );
  }
}

/// A parsed row: matched product with price, or an unmatched warning.
class BulkRowTile extends StatelessWidget {
  const BulkRowTile({super.key, required this.row});

  final BulkRow row;

  @override
  Widget build(BuildContext context) {
    final Product? p = row.product;
    if (p == null) {
      return AppCard(
        color: AppColors.warningTint,
        borderColor: AppColors.warningTint,
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            const Icon(Icons.help_outline_rounded, color: AppColors.warning),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.input, style: AppTypography.title),
                  Text('× ${row.quantity} · not in catalogue — can be quoted',
                      style: AppTypography.caption),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final int qty = row.quantity < p.moq ? p.moq : row.quantity;
    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ProductImage(
            source: p.primaryImage,
            size: 48,
            fallbackIcon: productFallbackIcon(context, p),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    style: AppTypography.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  '× $qty${row.size != null ? ' · Size ${row.size}' : ''}'
                  '${row.quantity < p.moq ? ' (raised to MOQ)' : ''}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          Text(formatInr(p.priceForQuantity(qty) * qty),
              style: AppTypography.bodyStrong),
        ],
      ),
    );
  }
}

//------------------------------------------------------------------------------
// Manual tab
//------------------------------------------------------------------------------
class ManualRow {
  Product? product;
  String? size;
  final TextEditingController qty = TextEditingController();

  void dispose() => qty.dispose();
}

class _ManualTab extends StatelessWidget {
  const _ManualTab({
    required this.rows,
    required this.onPickProduct,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });

  final List<ManualRow> rows;
  final ValueChanged<ManualRow> onPickProduct;
  final VoidCallback onAdd;
  final ValueChanged<ManualRow> onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ContentWidth(
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          for (int i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ManualRowCard(
                index: i + 1,
                row: rows[i],
                onPick: () => onPickProduct(rows[i]),
                onRemove: () => onRemove(rows[i]),
                onChanged: onChanged,
              ),
            ),
          SecondaryButton(
            label: 'Add Another Product',
            icon: Icons.add_rounded,
            color: AppColors.black,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _ManualRowCard extends StatelessWidget {
  const _ManualRowCard({
    required this.index,
    required this.row,
    required this.onPick,
    required this.onRemove,
    required this.onChanged,
  });

  final int index;
  final ManualRow row;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final Product? p = row.product;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Item $index', style: AppTypography.overline),
              const Spacer(),
              AppIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Remove',
                size: 28,
                iconSize: 16,
                color: AppColors.textMuted,
                onPressed: onRemove,
              ),
            ],
          ),
          InkWell(
            onTap: onPick,
            borderRadius: AppRadius.mdAll,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p?.name ?? 'Select product',
                      style: p == null
                          ? AppTypography.body.copyWith(color: AppColors.textMuted)
                          : AppTypography.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  controller: row.qty,
                  hint: p == null ? 'Quantity' : 'Qty (min ${p.moq})',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => onChanged(),
                ),
              ),
              if (p != null && p.sizes.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: AppDropdownField<String>(
                    hint: 'Size',
                    value: row.size,
                    items: p.sizes,
                    labelOf: (s) => s,
                    onChanged: (s) {
                      row.size = s;
                      onChanged();
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet({required this.catalog});

  final CatalogController catalog;

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String q = _query.text.trim();
    final List<Product> items =
        q.isEmpty ? widget.catalog.products : widget.catalog.search(q);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
          child: AppSearchBar(
            controller: _query,
            hint: 'Search products',
            onChanged: (_) => setState(() {}),
            onClear: () => setState(_query.clear),
          ),
        ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, i) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ProductImage(
                source: items[i].primaryImage,
                size: 44,
                fallbackIcon: productFallbackIcon(context, items[i]),
              ),
              title: Text(items[i].name, style: AppTypography.title),
              subtitle: Text(
                '${items[i].brand} · MOQ ${items[i].moq} · from ${formatInr(items[i].bestPrice)}',
                style: AppTypography.caption,
              ),
              onTap: () => Navigator.of(context).pop(items[i]),
            ),
          ),
        ),
      ],
    );
  }
}

//------------------------------------------------------------------------------
// Review
//------------------------------------------------------------------------------
class _ReviewList extends StatelessWidget {
  const _ReviewList({required this.rows});

  final List<BulkRow> rows;

  @override
  Widget build(BuildContext context) {
    final List<BulkRow> matched = rows.where((r) => r.product != null).toList();
    final List<BulkRow> unmatched = rows.where((r) => r.product == null).toList();
    double subtotal = 0;
    for (final BulkRow r in matched) {
      final Product p = r.product!;
      final int qty = r.quantity < p.moq ? p.moq : r.quantity;
      subtotal += p.priceForQuantity(qty) * qty;
    }

    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          Text('Matched (${matched.length})', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.xs),
          for (final BulkRow r in matched)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: BulkRowTile(row: r),
            ),
          if (matched.isEmpty)
            const Text('No catalogue matches in this list.',
                style: AppTypography.small),
          if (unmatched.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Not in catalogue (${unmatched.length})',
                style: AppTypography.h3),
            const SizedBox(height: AppSpacing.xs),
            for (final BulkRow r in unmatched)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: BulkRowTile(row: r),
              ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppCard(
            color: AppColors.surface,
            borderColor: AppColors.surface,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                SummaryRow(label: 'Subtotal', value: formatInr(subtotal)),
                SummaryRow(
                    label: 'GST (18%)',
                    value: formatInr(subtotal * CartController.gstRate)),
                const Divider(height: AppSpacing.md),
                SummaryRow(
                  label: 'Estimated total',
                  value: formatInr(subtotal * (1 + CartController.gstRate)),
                  emphasized: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
