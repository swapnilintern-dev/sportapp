import 'package:flutter/material.dart';

import '../../app/app_navigator.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/order.dart';
import '../../state/orders_controller.dart';

//==============================================================================
// SPOCART — My Orders
//------------------------------------------------------------------------------
// All / Pending / Shipped / Delivered tabs over the order history. Pull to
// refresh re-polls status. Rows open Order Details.
//==============================================================================

enum _OrderFilter { all, pending, shipped, delivered }

extension on _OrderFilter {
  String get label => switch (this) {
        _OrderFilter.all => 'All',
        _OrderFilter.pending => 'Pending',
        _OrderFilter.shipped => 'Shipped',
        _OrderFilter.delivered => 'Delivered',
      };

  bool matches(Order o) => switch (this) {
        _OrderFilter.all => true,
        _OrderFilter.pending => o.status.isPending,
        _OrderFilter.shipped => o.status.isShipped,
        _OrderFilter.delivered => o.status == OrderStatus.delivered,
      };
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, this.isTab = false});

  final bool isTab;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  _OrderFilter _filter = _OrderFilter.all;

  @override
  void initState() {
    super.initState();
    AppScope.of(context).orders.load();
  }

  @override
  Widget build(BuildContext context) {
    final OrdersController orders = AppScope.of(context).orders;
    return ListenableBuilder(
      listenable: orders,
      builder: (context, _) {
        final List<Order> visible =
            orders.orders.where(_filter.matches).toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: SpocartAppBar(
            title: 'My Orders',
            showBack: !widget.isTab,
          ),
          body: ContentWidth(
            child: Column(
              children: [
                _FilterTabs(
                  current: _filter,
                  onChanged: (f) => setState(() => _filter = f),
                ),
                Expanded(
                  child: AsyncStateView<List<Order>>(
                    loading: orders.loading,
                    error: orders.error,
                    data: orders.loaded ? visible : null,
                    onRetry: () => orders.load(force: true),
                    loadingBuilder: (_) => ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.page),
                      itemCount: 4,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, _) => const SkeletonBox(
                          height: 92, radius: AppRadius.lg),
                    ),
                    isEmpty: (list) => list.isEmpty,
                    emptyBuilder: (context) => orders.orders.isEmpty
                        ? EmptyStateView(
                            icon: Icons.receipt_long_outlined,
                            title: 'No orders yet',
                            message:
                                'Your placed orders and their tracking will appear here.',
                            actionLabel: 'Start Shopping',
                            onAction: () => AppNavigator.backToHome(
                              context,
                              tab: HomeTab.categories,
                            ),
                          )
                        : EmptyStateView(
                            icon: Icons.filter_list_off_rounded,
                            title: 'No ${_filter.label.toLowerCase()} orders',
                            message: 'Try another filter.',
                            actionLabel: 'Show All',
                            onAction: () =>
                                setState(() => _filter = _OrderFilter.all),
                          ),
                    builder: (context, list) => RefreshIndicator(
                      color: AppColors.red,
                      onRefresh: () => orders.load(force: true),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xl),
                        itemCount: list.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, i) => OrderCard(order: list[i]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.current, required this.onChanged});

  final _OrderFilter current;
  final ValueChanged<_OrderFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.page, vertical: 10),
        children: [
          for (final _OrderFilter f in _OrderFilter.values) ...[
            Material(
              color: f == current ? AppColors.red : AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.pillAll,
                side: BorderSide(
                    color: f == current ? AppColors.red : AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onChanged(f),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  child: Text(
                    f.label,
                    style: AppTypography.smallStrong.copyWith(
                      color: f == current ? AppColors.white : AppColors.text,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

/// Order summary row used on My Orders and the dashboard.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      onTap: () => AppNavigator.toOrderDetails(context, order.id),
      child: Row(
        children: [
          ProductImage(source: order.primaryImage, size: 60),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#${order.id}', style: AppTypography.title),
                const SizedBox(height: 2),
                Text(
                  '${formatDate(order.placedAt)} · ${pluralize(order.itemCount, 'item')} · ${formatInr(order.total)}',
                  style: AppTypography.small,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!order.paid)
                  Text('Payment due', style: AppTypography.caption.copyWith(color: AppColors.warning)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          StatusPill(label: order.status.label, color: order.status.color),
        ],
      ),
    );
  }
}
