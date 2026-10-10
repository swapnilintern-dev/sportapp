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
import '../../data/models/order.dart';
import '../../data/repositories/repositories.dart';
import '../../state/orders_controller.dart';
import 'invoice_pdf.dart';

//==============================================================================
// SPOCART — Invoices
//------------------------------------------------------------------------------
// One GST invoice per order. Download builds the PDF and opens the share
// sheet; tapping the row opens the order.
//==============================================================================

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  String? _busyInvoiceId;
  String? _payingInvoiceId;

  @override
  void initState() {
    super.initState();
    AppScope.of(context).orders.load();
  }

  Future<void> _download(Order order) async {
    if (_busyInvoiceId != null) return;
    setState(() => _busyInvoiceId = order.invoiceId);
    try {
      await shareInvoicePdf(context, order);
    } finally {
      if (mounted) setState(() => _busyInvoiceId = null);
    }
  }

  /// Settles an unpaid Pay Later invoice online. The server opens a fresh
  /// Razorpay session against the same order, so the order is paid for here
  /// exactly as it would have been at checkout.
  Future<void> _payInvoice(Order order) async {
    if (_payingInvoiceId != null) return;
    setState(() => _payingInvoiceId = order.invoiceId);
    try {
      final CheckoutSession checkout =
          await AppScope.of(context).orders.payInvoice(order.invoiceId);
      if (!mounted) return;
      AppNavigator.toRazorpayCheckout(
        context,
        order: order,
        checkout: checkout,
        replace: false,
      );
    } on AppException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, tone: SnackTone.error);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Could not start the payment. Please try again.',
          tone: SnackTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _payingInvoiceId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final OrdersController orders = AppScope.of(context).orders;
    return ListenableBuilder(
      listenable: orders,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: const SpocartAppBar(title: 'GST Invoices'),
          body: AsyncStateView<List<Order>>(
            loading: orders.loading,
            error: orders.error,
            data: orders.loaded
                ? orders.orders
                    .where((o) => !o.status.awaitingPayment && o.status != OrderStatus.cancelled)
                    .toList()
                : null,
            onRetry: () => orders.load(force: true),
            isEmpty: (list) => list.isEmpty,
            emptyBuilder: (context) => EmptyStateView(
              icon: Icons.receipt_outlined,
              title: 'No invoices yet',
              message: 'A GST invoice is generated for every order you place.',
              actionLabel: 'Start Shopping',
              onAction: () => AppNavigator.backToHome(
                context,
                tab: HomeTab.categories,
              ),
            ),
            builder: (context, list) => ContentWidth(
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.page),
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final Order o = list[i];
                  final bool busy = _busyInvoiceId == o.invoiceId;
                  return AppCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 10),
                    onTap: () => AppNavigator.toOrderDetails(context, o.id),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: AppRadius.smAll,
                              ),
                              child: const Icon(Icons.description_outlined,
                                  size: 20, color: AppColors.black),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('#${o.invoiceId}',
                                      style: AppTypography.title),
                                  Text(
                                    '${formatDate(o.placedAt)} · Order ${o.id}',
                                    style: AppTypography.caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(formatInr(o.total),
                                    style: AppTypography.bodyStrong),
                                StatusPill(
                                  label: o.paid ? 'Paid' : 'Due',
                                  color: o.paid
                                      ? AppColors.success
                                      : AppColors.warning,
                                  dense: true,
                                ),
                              ],
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            SizedBox(
                              width: 92,
                              child: PrimaryButton(
                                label: 'Download',
                                size: ButtonSize.small,
                                loading: busy,
                                onPressed: () => _download(o),
                              ),
                            ),
                          ],
                        ),
                        // Pay Later invoices can be settled online. It sits
                        // below the row rather than in it — four controls on
                        // one line does not fit a phone.
                        if (!o.paid) ...[
                          const SizedBox(height: AppSpacing.xs),
                          PrimaryButton(
                            label: 'Pay ${formatInr(o.total)}',
                            size: ButtonSize.small,
                            loading: _payingInvoiceId == o.invoiceId,
                            onPressed: () => _payInvoice(o),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
