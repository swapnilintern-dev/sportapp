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
import '../../state/notifications_controller.dart';

//==============================================================================
// SPOCART — Notifications
//------------------------------------------------------------------------------
// Inbox of order / quote / offer events. Tapping opens the linked order,
// product or quotation and marks the entry read.
//==============================================================================

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    AppScope.of(context).notifications.load();
  }

  Future<void> _open(AppNotification n) async {
    final NotificationsController notifications =
        AppScope.of(context).notifications;
    await notifications.markRead(n.id);
    if (!mounted) return;
    if (n.orderId != null) {
      await AppNavigator.toOrderDetails(context, n.orderId!);
    } else if (n.productId != null) {
      await AppNavigator.toProductById(context, n.productId!);
    } else if (n.quoteId != null) {
      await AppNavigator.toQuotes(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final NotificationsController notifications =
        AppScope.of(context).notifications;
    return ListenableBuilder(
      listenable: notifications,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: SpocartAppBar(
            title: 'Notifications',
            actions: [
              if (notifications.unreadCount > 0)
                GhostButton(
                  label: 'Mark all read',
                  onPressed: notifications.markAllRead,
                ),
              if (notifications.items.isNotEmpty)
                AppIconButton(
                  icon: Icons.delete_sweep_outlined,
                  tooltip: 'Clear all',
                  onPressed: () async {
                    final bool ok = await showAppConfirmDialog(
                      context,
                      title: 'Clear notifications?',
                      message: 'All notifications will be removed.',
                      confirmLabel: 'Clear',
                      destructive: true,
                    );
                    if (ok) notifications.clearAll();
                  },
                ),
            ],
          ),
          body: AsyncStateView<List<AppNotification>>(
            loading: notifications.loading,
            error: notifications.error,
            data: notifications.loaded ? notifications.items : null,
            onRetry: () => notifications.load(force: true),
            isEmpty: (list) => list.isEmpty,
            emptyBuilder: (context) => const EmptyStateView(
              icon: Icons.notifications_none_rounded,
              title: 'You’re all caught up',
              message:
                  'Order updates, quotation replies and offers will show up here.',
            ),
            builder: (context, list) => RefreshIndicator(
              color: AppColors.red,
              onRefresh: () => notifications.load(force: true),
              child: ContentWidth(
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.page),
                  itemCount: list.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, i) => _NotificationTile(
                    item: list[i],
                    onTap: () => _open(list[i]),
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

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool linked =
        item.orderId != null || item.productId != null || item.quoteId != null;
    return AppCard(
      onTap: onTap,
      color: item.read ? AppColors.white : AppColors.surface,
      borderColor: item.read ? AppColors.border : AppColors.surface,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.type.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(item.type.icon, size: 20, color: item.type.color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: item.read
                            ? AppTypography.title
                            : AppTypography.title.copyWith(
                                fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(formatRelative(item.time), style: AppTypography.caption),
                  ],
                ),
                const SizedBox(height: 2),
                Text(item.body, style: AppTypography.small),
                if (linked)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      item.orderId != null
                          ? 'View order'
                          : item.productId != null
                              ? 'View product'
                              : 'View quotation',
                      style: AppTypography.smallStrong
                          .copyWith(color: AppColors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          if (!item.read)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(left: 6, top: 6),
              decoration: const BoxDecoration(
                color: AppColors.red,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
