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
import '../../data/models/account.dart';
import '../../data/models/catalog.dart';
import '../../data/models/order.dart';
import '../../data/repositories/repositories.dart';
import '../../state/address_controller.dart';
import '../../state/analytics_controller.dart';
import '../../state/cart_controller.dart';

//==============================================================================
// SPOCART — Checkout
//------------------------------------------------------------------------------
// Delivery address (select / add), payment method and the order summary.
// Continue → UPI payment screen, or places a Pay Later order against the
// business-credit limit. Net banking, cards and wallets need a payment
// gateway that is not integrated yet, so they are shown disabled with the
// reason rather than pretending to work.
//==============================================================================

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String? _addressId;
  PaymentMethod _payment = PaymentMethod.upi;
  bool _placing = false;

  /// Every online method runs through one Razorpay checkout; the demo backend
  /// has no gateway, so it only offers business credit.
  Set<PaymentMethod> get _enabledMethods => AppScope.of(context).isDemo
      ? const <PaymentMethod>{PaymentMethod.payLater}
      : PaymentMethod.values.toSet();

  @override
  void initState() {
    super.initState();
    final AppServices services = AppScope.of(context);
    services.addresses.load();
    services.orders.load();
    if (services.isDemo) _payment = PaymentMethod.payLater;
    _loadCredit();
  }

  double? _availableCredit;

  Future<void> _loadCredit() async {
    final AppServices services = AppScope.of(context);
    try {
      await services.orders.loadDashboard(
        creditLimit: services.session.session?.creditLimit ?? 0,
      );
      if (mounted) {
        setState(() => _availableCredit = services.orders.dashboard?.availableCredit);
      }
    } catch (_) {
      // Credit is re-checked by the server when the order is placed.
    }
  }

  Address? _selectedAddress(AddressController addresses) {
    if (_addressId != null) {
      final Address? a = addresses.byId(_addressId!);
      if (a != null) return a;
    }
    return addresses.defaultAddress;
  }

  Future<void> _addAddress() async {
    final Address? saved = await AppNavigator.toAddressForm(context);
    if (saved != null && mounted) setState(() => _addressId = saved.id);
  }

  Future<void> _continue() async {
    if (_placing) return;
    final AppServices services = AppScope.of(context);
    services.analytics.log(AppEvent.checkoutStart);
    final CartController cart = services.cart;

    if (cart.isEmpty) {
      showAppSnackBar(context, 'Your cart is empty.', tone: SnackTone.error);
      return;
    }

    // Sized products must carry a size; the server rejects such a line, so say
    // so here and send the buyer to the cart where it can be fixed.
    final List<CartLine> sizeless = cart.missingSize;
    if (sizeless.isNotEmpty) {
      final Product? p = cart.productOf(sizeless.first);
      showAppSnackBar(
        context,
        '${p?.name ?? 'One item'} needs a size before you can check out.',
        tone: SnackTone.error,
        actionLabel: 'Open Cart',
        onAction: () => AppNavigator.backToHome(context, tab: HomeTab.cart),
      );
      return;
    }

    if (!services.session.isRegistered) {
      final bool saved =
          await AppNavigator.toBusinessRegistration(context, allowSkip: false);
      if (!saved || !mounted) {
        if (mounted) {
          showAppSnackBar(
            context,
            'Business details are required to place an order.',
            tone: SnackTone.error,
          );
        }
        return;
      }
    }

    final Address? address = _selectedAddress(services.addresses);
    if (address == null) {
      showAppSnackBar(context, 'Please add a delivery address.',
          tone: SnackTone.error);
      return;
    }

    if (_payment == PaymentMethod.payLater) {
      final double? available = _availableCredit;
      if (available != null && cart.total > available) {
        showAppSnackBar(
          context,
          'Order total exceeds your available credit of ${formatInr(available)}. Pay online or reduce the order.',
          tone: SnackTone.error,
          duration: const Duration(seconds: 5),
        );
        return;
      }
      final bool ok = await showAppConfirmDialog(
        context,
        title: 'Place order on credit?',
        message:
            '${formatInr(cart.total)} will be invoiced to your business credit, payable within 30 days.',
        confirmLabel: 'Place Order',
        icon: Icons.schedule_rounded,
      );
      if (!ok || !mounted) return;
    }
    await _placeOrder(address);
  }

  Future<void> _placeOrder(Address address) async {
    // Order creation is not idempotent: never let a second tap through, and
    // never retry it automatically.
    if (_placing) return;
    final AppServices services = AppScope.of(context);
    setState(() => _placing = true);
    try {
      final PlaceOrderResult result = await services.orders.placeOrder(
        cart: services.cart,
        address: address,
        paymentMethod: _payment,
      );
      if (!mounted) return;
      services.analytics
          .log(AppEvent.orderPlaced, orderId: result.order.id);
      if (result.checkout == null) {
        // Pay Later (or demo): the order is placed; nothing left to pay now.
        services.cart.clear();
        AppNavigator.toOrderConfirmation(context, result.order);
      } else {
        AppNavigator.toRazorpayCheckout(context, order: result.order, checkout: result.checkout!);
      }
    } on AppException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, tone: SnackTone.error);
    } catch (_) {
      // Only reached when the failure carried no message we can show — an
      // AppException (including every server validation error) is surfaced
      // verbatim above.
      if (mounted) {
        showAppSnackBar(
          context,
          'Could not place the order. Please try again.',
          tone: SnackTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        services.cart,
        services.addresses,
        services.orders,
        services.session,
      ]),
      builder: (context, _) {
        final CartController cart = services.cart;
        final AddressController addresses = services.addresses;
        final Address? selected = _selectedAddress(addresses);
        final double? credit = _availableCredit;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: const SpocartAppBar(title: 'Checkout'),
          body: cart.isEmpty
              ? EmptyStateView(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Nothing to check out',
                  message: 'Your cart is empty.',
                  actionLabel: 'Browse Products',
                  onAction: () => AppNavigator.backToHome(
                    context,
                    tab: HomeTab.categories,
                  ),
                )
              : ContentWidth(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xl),
                    children: [
                      SectionHeader(
                        title: 'Delivery Address',
                        padding: EdgeInsets.zero,
                        actionLabel: 'Add New Address',
                        onAction: _addAddress,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (addresses.loading && !addresses.loaded)
                        const SkeletonBox(height: 96, radius: AppRadius.lg)
                      else if (addresses.isEmpty)
                        _NoAddress(onAdd: _addAddress)
                      else ...[
                        for (final Address a in addresses.addresses)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: _AddressOption(
                              address: a,
                              selected: a.id == selected?.id,
                              onTap: () => setState(() => _addressId = a.id),
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GhostButton(
                            label: 'Manage addresses',
                            icon: Icons.edit_location_alt_outlined,
                            color: AppColors.textSoft,
                            onPressed: () => AppNavigator.toAddresses(context),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      const Text('Payment Method', style: AppTypography.h3),
                      const SizedBox(height: AppSpacing.sm),
                      for (final PaymentMethod m in PaymentMethod.values)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _PaymentOption(
                            method: m,
                            selected: _payment == m,
                            enabled: _enabledMethods.contains(m),
                            detail: m == PaymentMethod.payLater && credit != null
                                ? 'Available credit ${formatInr(credit)}'
                                : null,
                            onTap: () => setState(() => _payment = m),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      const Text('Order Summary', style: AppTypography.h3),
                      const SizedBox(height: AppSpacing.sm),
                      AppCard(
                        color: AppColors.surface,
                        borderColor: AppColors.surface,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          children: [
                            SummaryRow(
                              label: 'Items (${cart.totalUnits} units)',
                              value: formatInr(cart.subtotal),
                            ),
                            SummaryRow(
                              label: 'GST (18%)',
                              value: formatInr(cart.gst),
                            ),
                            const SummaryRow(label: 'Delivery', value: 'Free'),
                            const Divider(height: AppSpacing.md),
                            SummaryRow(
                              label: 'Total',
                              value: formatInr(cart.total),
                              emphasized: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          bottomNavigationBar: cart.isEmpty
              ? null
              : BottomActionBar(
                  child: PrimaryButton(
                    label: _payment == PaymentMethod.payLater
                        ? 'Place Order on Credit'
                        : 'Continue to Pay ${formatInr(cart.total)}',
                    loading: _placing,
                    onPressed: _continue,
                  ),
                ),
        );
      },
    );
  }
}

class _NoAddress extends StatelessWidget {
  const _NoAddress({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onAdd,
      color: AppColors.surface,
      borderColor: AppColors.border,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.add_location_alt_outlined, color: AppColors.red),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text(
              'No delivery address yet. Add one to continue.',
              style: AppTypography.body,
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _AddressOption extends StatelessWidget {
  const _AddressOption({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final Address address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      borderColor: selected ? AppColors.red : AppColors.border,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioDot(selected: selected),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(address.contactName,
                          style: AppTypography.title),
                    ),
                    StatusPill(
                      label: address.label.label,
                      color: AppColors.textSoft,
                      background: AppColors.surfaceAlt,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(address.summary, style: AppTypography.small),
                Text(formatIndianMobile(address.mobile),
                    style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.method,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.detail,
  });

  final PaymentMethod method;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: AppCard(
        onTap: enabled ? onTap : null,
        borderColor: selected ? AppColors.red : AppColors.border,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 10),
        child: Row(
          children: [
            RadioDot(selected: selected && enabled),
            const SizedBox(width: AppSpacing.sm),
            Icon(method.icon, size: 22, color: AppColors.text),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(method.title, style: AppTypography.title),
                  Text(
                    enabled
                        ? (detail ?? method.subtitle)
                        : 'Available with the SPOCART server',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Red ring radio indicator used on selectable cards.
class RadioDot extends StatelessWidget {
  const RadioDot({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.fast,
      width: 20,
      height: 20,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.red : AppColors.textMuted,
          width: selected ? 6 : 1.6,
        ),
      ),
    );
  }
}
