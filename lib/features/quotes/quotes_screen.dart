import 'package:flutter/material.dart';

import '../../app/app_navigator.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/engagement.dart';
import '../../state/quotes_controller.dart';
import '../support/help_sheet.dart';

//==============================================================================
// SPOCART — Quotations
//------------------------------------------------------------------------------
// Every quote request the buyer has raised (bulk, custom kit, CSV upload)
// with its status. Tapping shows the items and lets them chase the team.
//==============================================================================

class QuotesScreen extends StatefulWidget {
  const QuotesScreen({super.key});

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  @override
  void initState() {
    super.initState();
    AppScope.of(context).quotes.load();
  }

  void _openQuote(QuoteRequest q) {
    showAppBottomSheet<void>(
      context,
      title: q.id,
      builder: (context) => _QuoteDetail(quote: q),
    );
  }

  @override
  Widget build(BuildContext context) {
    final QuotesController quotes = AppScope.of(context).quotes;
    return ListenableBuilder(
      listenable: quotes,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: const SpocartAppBar(title: 'Quotations'),
          body: AsyncStateView<List<QuoteRequest>>(
            loading: quotes.loading,
            error: quotes.error,
            data: quotes.loaded ? quotes.quotes : null,
            onRetry: () => quotes.load(force: true),
            isEmpty: (list) => list.isEmpty,
            emptyBuilder: (context) => EmptyStateView(
              icon: Icons.request_quote_outlined,
              title: 'No quotations yet',
              message:
                  'Request a quote from any product’s Bulk Pricing page or start a custom team order.',
              actionLabel: 'Custom / Team Order',
              onAction: () => AppNavigator.toCustomOrder(context),
            ),
            builder: (context, list) => RefreshIndicator(
              color: AppColors.red,
              onRefresh: () => quotes.load(force: true),
              child: ContentWidth(
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.page),
                  itemCount: list.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _QuoteCard(
                    quote: list[i],
                    onTap: () => _openQuote(list[i]),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote, required this.onTap});

  final QuoteRequest quote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String items = quote.items.isEmpty
        ? '—'
        : quote.items.length == 1
            ? quote.items.first.description
            : '${quote.items.first.description} +${quote.items.length - 1} more';
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(
              switch (quote.kind) {
                QuoteKind.bulk => Icons.layers_outlined,
                QuoteKind.custom => Icons.checkroom_outlined,
                QuoteKind.csv => Icons.upload_file_outlined,
              },
              color: AppColors.black,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quote.id, style: AppTypography.title),
                Text(items,
                    style: AppTypography.small,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  '${quote.kind.label} · ${quote.totalUnits} units · ${formatDate(quote.createdAt)}',
                  style: AppTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          StatusPill(label: quote.status.label, color: quote.status.color),
        ],
      ),
    );
  }
}

class _QuoteDetail extends StatelessWidget {
  const _QuoteDetail({required this.quote});

  final QuoteRequest quote;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${quote.kind.label} · ${formatDateTime(quote.createdAt)}',
                  style: AppTypography.small,
                ),
              ),
              StatusPill(label: quote.status.label, color: quote.status.color),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('Items', style: AppTypography.overline),
          const SizedBox(height: AppSpacing.xs),
          for (final QuoteItem item in quote.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.size == null
                          ? item.description
                          : '${item.description} (Size ${item.size})',
                      style: AppTypography.body,
                    ),
                  ),
                  Text('× ${item.quantity}', style: AppTypography.bodyStrong),
                ],
              ),
            ),
          if (quote.designFileName != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.attach_file_rounded,
                    size: 16, color: AppColors.textSoft),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(quote.designFileName!,
                      style: AppTypography.small,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
          if (quote.notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const Text('Requirements', style: AppTypography.overline),
            const SizedBox(height: AppSpacing.xs),
            Text(quote.notes, style: AppTypography.bodyMuted),
          ],
          if (quote.quotedTotal != null) ...[
            const SizedBox(height: AppSpacing.md),
            SummaryRow(
              label: 'Quoted total',
              value: formatInr(quote.quotedTotal!),
              emphasized: true,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SecondaryButton(
            label: 'Discuss on WhatsApp',
            icon: Icons.chat_bubble_outline_rounded,
            color: AppColors.black,
            onPressed: () => SupportLauncher.whatsapp(
              context,
              message: 'Hi SPOCART, following up on quotation ${quote.id}.',
            ),
          ),
        ],
      ),
    );
  }
}
