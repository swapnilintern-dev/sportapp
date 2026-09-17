import 'package:flutter/material.dart';

import '../../app/app_navigator.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/order.dart';
import '../../state/orders_controller.dart';
import '../orders/orders_screen.dart';
import '../support/help_sheet.dart';

//==============================================================================
// SPOCART — Business dashboard
//------------------------------------------------------------------------------
// Six live stats derived from the account's orders and quotes, quick
// actions, and the most recent orders.
//==============================================================================

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    final AppServices services = AppScope.of(context);
    services.orders.load();
    services.quotes.load();
  }

  Future<void> _refresh() async {
    final AppServices services = AppScope.of(context);
    await Future.wait<void>(<Future<void>>[
      services.orders.load(force: true),
      services.quotes.load(force: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.of(context);
    final OrdersController orders = services.orders;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SpocartAppBar(title: 'Business Dashboard'),
      body: ListenableBuilder(
        listenable: Listenable.merge(
            [orders, services.quotes, services.session]),
        builder: (context, _) {
          if (orders.error != null && !orders.loaded) {
            return ErrorStateView(
              message: orders.error,
              onRetry: _refresh,
            );
          }
          final bool loading = !orders.loaded || !services.quotes.loaded;
          final double creditLimit =
              services.session.session?.creditLimit ?? 0;
          final double available =
              (creditLimit - orders.outstandingPayment).clamp(0, creditLimit);
          final List<Order> recent = orders.orders.take(3).toList();

          return RefreshIndicator(
            color: AppColors.red,
            onRefresh: _refresh,
            child: ContentWidth(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.page),
                children: [
                  _StatGrid(
                    loading: loading,
                    stats: [
                      _Stat('Total Purchases', formatInr(orders.totalPurchases),
                          Icons.payments_outlined,
                          onTap: () => AppNavigator.backToHome(context,
                              tab: HomeTab.orders)),
                      _Stat('Pending Orders', '${orders.pendingCount}',
                          Icons.pending_actions_outlined,
                          onTap: () => AppNavigator.backToHome(context,
                              tab: HomeTab.orders)),
                      _Stat('Outstanding Payment',
                          formatInr(orders.outstandingPayment),
                          Icons.account_balance_wallet_outlined,
                          onTap: () => AppNavigator.toInvoices(context)),
                      _Stat('Saved Quotations', '${services.quotes.count}',
                          Icons.request_quote_outlined,
                          onTap: () => AppNavigator.toQuotes(context)),
                      _Stat('Repeat Orders', '${orders.repeatOrderCount}',
                          Icons.repeat_rounded,
                          onTap: () => AppNavigator.backToHome(context,
                              tab: HomeTab.orders)),
                      _Stat('Available Credit', formatInr(available),
                          Icons.credit_score_outlined,
                          onTap: () => AppNavigator.toInvoices(context)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Text('Quick Actions', style: AppTypography.h3),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      _QuickAction(
                        icon: Icons.add_shopping_cart_rounded,
                        label: 'Add Product',
                        onTap: () => AppNavigator.backToHome(context,
                            tab: HomeTab.categories),
                      ),
                      _QuickAction(
                        icon: Icons.upload_file_outlined,
                        label: 'Bulk Order',
                        onTap: () => AppNavigator.toBulkUpload(context),
                      ),
                      _QuickAction(
                        icon: Icons.checkroom_outlined,
                        label: 'Custom Order',
                        onTap: () => AppNavigator.toCustomOrder(context),
                      ),
                      _QuickAction(
                        icon: Icons.headset_mic_outlined,
                        label: 'Support',
                        onTap: () => showHelpSheet(context,
                            title: 'How can we help?'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    title: 'Recent Orders',
                    padding: EdgeInsets.zero,
                    actionLabel: recent.isEmpty ? null : 'View All',
                    onAction: () =>
                        AppNavigator.backToHome(context, tab: HomeTab.orders),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (loading)
                    const SkeletonBox(height: 84, radius: AppRadius.lg)
                  else if (recent.isEmpty)
                    const EmptyStateView(
                      icon: Icons.receipt_long_outlined,
                      title: 'No orders yet',
                      message: 'Your stats fill in as you order.',
                      compact: true,
                    )
                  else
                    for (final Order o in recent)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: OrderCard(order: o),
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

class _Stat {
  const _Stat(this.label, this.value, this.icon, {required this.onTap});

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats, required this.loading});

  final List<_Stat> stats;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns = constraints.maxWidth >= 480 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.55,
          ),
          itemCount: stats.length,
          itemBuilder: (context, i) => AppCard(
            onTap: stats[i].onTap,
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(stats[i].icon, size: 18, color: AppColors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        stats[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption,
                      ),
                    ),
                  ],
                ),
                loading
                    ? const SkeletonBox(width: 80, height: 20)
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(stats[i].value, style: AppTypography.h2),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.black,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Icon(icon, color: AppColors.white, size: 24),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
