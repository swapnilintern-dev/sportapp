import 'package:flutter/material.dart';

import '../../app/app_navigator.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/layout.dart';
import '../../data/models/order.dart';

//==============================================================================
// SPOCART — Order confirmation
//------------------------------------------------------------------------------
// Success state after checkout: order id, estimated delivery window and the
// two exits (order details / keep shopping). Back goes home, never into the
// completed payment flow.
//==============================================================================

class OrderConfirmationScreen extends StatefulWidget {
  const OrderConfirmationScreen({super.key, required this.order});

  final Order order;

  @override
  State<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Order order = widget.order;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) AppNavigator.backToHome(context, tab: HomeTab.orders);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: ContentWidth(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  const Spacer(),
                  ScaleTransition(
                    scale: CurvedAnimation(parent: _pop, curve: Curves.elasticOut),
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        color: AppColors.successTint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
                          size: 56, color: AppColors.success),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Text('Order Placed!', style: AppTypography.display),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Your order has been placed successfully.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMuted,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text.rich(
                    TextSpan(
                      text: 'Order ID: ',
                      style: AppTypography.body,
                      children: [
                        TextSpan(text: order.id, style: AppTypography.h3),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: Column(
                      children: [
                        const Text('Estimated Delivery',
                            style: AppTypography.caption),
                        const SizedBox(height: 2),
                        Text(
                          formatDateRange(order.etaStart, order.etaEnd),
                          style: AppTypography.title,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    order.paid
                        ? '${formatInr(order.total)} paid via ${order.paymentMethod.title}'
                        : '${formatInr(order.total)} on business credit · due in 30 days',
                    style: AppTypography.small,
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  PrimaryButton(
                    label: 'View Order Details',
                    onPressed: () =>
                        AppNavigator.toOrderDetails(context, order.id),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryButton(
                    label: 'Continue Shopping',
                    color: AppColors.black,
                    onPressed: () => AppNavigator.backToHome(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
