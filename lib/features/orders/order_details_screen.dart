import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_navigator.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/order.dart';
import '../../data/repositories/repositories.dart';
import '../../state/orders_controller.dart';
import '../invoices/invoice_pdf.dart';
import '../support/help_sheet.dart';

//==============================================================================
// SPOCART — Order details / tracking
//------------------------------------------------------------------------------
// Status header, five-step tracking timeline, shipping address, items and
// totals. "Track Shipment" opens the courier sheet (tracking id + copy);
// invoice download and help are one tap away.
//==============================================================================

class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  @override
  void initState() {
    super.initState();
    AppScope.of(context).orders.load();
  }

  bool _paying = false;

  /// Reopens Razorpay for an order whose payment was cancelled or failed.
  Future<void> _payNow(Order order) async {
    if (_paying) return;
    setState(() => _paying = true);
    try {
      final PlaceOrderResult fresh =
          await AppScope.of(context).orders.retryPayment(order.id);
      if (!mounted) return;
      if (fresh.checkout == null) {
        showAppSnackBar(context, 'This order no longer needs a payment.');
        return;
      }
      AppNavigator.toRazorpayCheckout(context, order: fresh.order, checkout: fresh.checkout!);
    } on AppException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, tone: SnackTone.error);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _trackShipment(Order order) {
    showAppBottomSheet<void>(
      context,
      title: 'Track Shipment',
      builder: (context) => _TrackingSheet(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final OrdersController orders = AppScope.of(context).orders;
    return ListenableBuilder(
      listenable: orders,
      builder: (context, _) {
        final Order? order = orders.byId(widget.orderId);
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: SpocartAppBar(
            title: 'Order ${widget.orderId}',
            actions: [
              AppIconButton(
                icon: Icons.headset_mic_outlined,
                tooltip: 'Help',
                onPressed: () =>
                    showHelpSheet(context, about: 'Order ${widget.orderId}'),
              ),
            ],
          ),
          body: order == null
              ? (orders.loading
                  ? const AppLoader()
                  : EmptyStateView(
                      icon: Icons.search_off_rounded,
                      title: 'Order not found',
                      message: 'We could not find order ${widget.orderId}.',
                      actionLabel: 'My Orders',
                      onAction: () => AppNavigator.backToHome(
                        context,
                        tab: HomeTab.orders,
                      ),
                    ))
              : RefreshIndicator(
                  color: AppColors.red,
                  onRefresh: () => orders.load(force: true),
                  child: ContentWidth(
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xl),
                      children: [
                        _Header(order: order),
                        const SizedBox(height: AppSpacing.lg),
                        _Timeline(order: order),
                        const SizedBox(height: AppSpacing.lg),
                        const Text('Shipping Address', style: AppTypography.h3),
                        const SizedBox(height: AppSpacing.xs),
                        AppCard(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 20, color: AppColors.red),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(order.address.contactName,
                                        style: AppTypography.title),
                                    Text(order.address.multiline,
                                        style: AppTypography.small),
                                    Text(formatIndianMobile(order.address.mobile),
                                        style: AppTypography.caption),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text('Items (${order.itemCount})',
                            style: AppTypography.h3),
                        const SizedBox(height: AppSpacing.xs),
                        for (final OrderLine l in order.lines)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: _LineTile(line: l),
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        AppCard(
                          color: AppColors.surface,
                          borderColor: AppColors.surface,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            children: [
                              SummaryRow(
                                  label: 'Subtotal',
                                  value: formatInr(order.subtotal)),
                              SummaryRow(
                                  label: 'GST (18%)',
                                  value: formatInr(order.gst)),
                              const Divider(height: AppSpacing.md),
                              SummaryRow(
                                label: 'Total',
                                value: formatInr(order.total),
                                emphasized: true,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(order.paymentMethod.icon,
                                      size: 16, color: AppColors.textSoft),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      order.paid
                                          ? 'Paid via ${order.paymentMethod.title}'
                                          : '${order.paymentMethod.title} · payment due within 30 days',
                                      style: AppTypography.caption,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SecondaryButton(
                          label: 'Download Invoice ${order.invoiceId}',
                          icon: Icons.download_rounded,
                          color: AppColors.black,
                          onPressed: () => shareInvoicePdf(context, order),
                        ),
                      ],
                    ),
                  ),
                ),
          bottomNavigationBar: order == null || !order.status.isOpen
              ? null
              : BottomActionBar(
                  child: order.status.awaitingPayment
                      ? PrimaryButton(
                          label: 'Pay ${formatInr(order.total)} Now',
                          icon: Icons.lock_outline_rounded,
                          loading: _paying,
                          onPressed: () => _payNow(order),
                        )
                      : PrimaryButton(
                          label: 'Track Shipment',
                          icon: Icons.local_shipping_outlined,
                          onPressed: () => _trackShipment(order),
                        ),
                ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('#${order.id}', style: AppTypography.h2),
              const SizedBox(height: 2),
              Text(
                '${formatDate(order.placedAt)} · ${pluralize(order.itemCount, 'item')} · ${order.totalUnits} units',
                style: AppTypography.small,
              ),
            ],
          ),
        ),
        StatusPill(label: order.status.label, color: order.status.color),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final int active = order.trackingIndex;
    final bool cancelled = order.status == OrderStatus.cancelled;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.md, AppSpacing.sm, AppSpacing.sm),
      child: Column(
        children: [
          Row(
            children: [
              for (int i = 0; i < kTrackingSteps.length; i++) ...[
                _StepDot(
                  done: !cancelled && i <= active,
                  current: !cancelled && i == active,
                  icon: kTrackingSteps[i].icon,
                ),
                if (i < kTrackingSteps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: !cancelled && i < active
                          ? AppColors.red
                          : AppColors.border,
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              for (int i = 0; i < kTrackingSteps.length; i++)
                Expanded(
                  child: Text(
                    kTrackingSteps[i].stepTitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      fontWeight: !cancelled && i == active
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: !cancelled && i <= active
                          ? AppColors.text
                          : AppColors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(cancelled ? Icons.cancel_outlined : Icons.schedule_rounded,
                  size: 16, color: AppColors.textSoft),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  cancelled
                      ? 'This order was cancelled.'
                      : order.status == OrderStatus.delivered
                          ? 'Delivered ${order.statusUpdatedAt == null ? '' : formatDateTime(order.statusUpdatedAt!)}'
                          : 'Estimated delivery ${formatDateRange(order.etaStart, order.etaEnd)}',
                  style: AppTypography.small,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.done,
    required this.current,
    required this.icon,
  });

  final bool done;
  final bool current;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: done ? AppColors.red : AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: done ? AppColors.red : AppColors.border,
          width: current ? 3 : 1.5,
        ),
        boxShadow: current ? AppShadows.red : null,
      ),
      child: Icon(
        done ? Icons.check_rounded : icon,
        size: 15,
        color: done ? AppColors.white : AppColors.textMuted,
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line});

  final OrderLine line;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: () => AppNavigator.toProductById(context, line.productId),
      child: Row(
        children: [
          ProductImage(source: line.image, size: 52),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name,
                    style: AppTypography.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  '${line.quantity} × ${formatInr(line.unitPrice)} / ${line.unit}'
                  '${line.size != null ? ' · Size ${line.size}' : ''}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          Text(formatInr(line.lineTotal), style: AppTypography.bodyStrong),
        ],
      ),
    );
  }
}

class _TrackingSheet extends StatelessWidget {
  const _TrackingSheet({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final String trackingId = order.trackingId ?? '—';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _KV(label: 'Status', value: order.status.label),
          _KV(label: 'Courier', value: 'SPOCART Logistics'),
          _KV(label: 'Tracking ID', value: trackingId),
          _KV(
            label: 'Last update',
            value: order.statusUpdatedAt == null
                ? formatDateTime(order.placedAt)
                : formatDateTime(order.statusUpdatedAt!),
          ),
          _KV(
            label: 'Expected',
            value: formatDateRange(order.etaStart, order.etaEnd),
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: 'Copy Tracking ID',
            icon: Icons.copy_rounded,
            color: AppColors.black,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: trackingId));
              if (context.mounted) {
                showAppSnackBar(context, 'Tracking ID copied',
                    tone: SnackTone.success);
              }
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          GhostButton(
            label: 'Contact support about this shipment',
            color: AppColors.textSoft,
            onPressed: () {
              Navigator.of(context).pop();
              showHelpSheet(context, about: 'Shipment for order ${order.id}');
            },
          ),
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: AppTypography.small),
          ),
          Expanded(child: Text(value, style: AppTypography.bodyStrong)),
        ],
      ),
    );
  }
}
