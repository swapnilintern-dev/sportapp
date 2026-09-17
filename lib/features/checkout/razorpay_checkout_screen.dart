import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../app/app_navigator.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../data/models/order.dart';
import '../../data/repositories/repositories.dart';
import '../support/help_sheet.dart';

//==============================================================================
// SPOCART — Razorpay checkout
//------------------------------------------------------------------------------
// Opens the Razorpay sheet (UPI, cards, net banking, wallets) for an order the
// API created in `paymentPending`. On success the three Razorpay ids are sent
// to /orders/payments/verify; the API checks the signature and marks the
// order placed. Failure / dismissal keeps the order so the buyer can retry.
//==============================================================================

class RazorpayCheckoutScreen extends StatefulWidget {
  const RazorpayCheckoutScreen({
    super.key,
    required this.order,
    required this.checkout,
  });

  final Order order;
  final CheckoutSession checkout;

  @override
  State<RazorpayCheckoutScreen> createState() => _RazorpayCheckoutScreenState();
}

class _RazorpayCheckoutScreenState extends State<RazorpayCheckoutScreen> {
  late final Razorpay _razorpay = Razorpay();
  late CheckoutSession _checkout = widget.checkout;
  bool _opening = false;
  bool _confirming = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _open() {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      _razorpay.open(<String, dynamic>{
        'key': _checkout.keyId,
        'order_id': _checkout.razorpayOrderId,
        'amount': _checkout.amountPaise,
        'currency': 'INR',
        'name': 'SPOCART',
        'description': _checkout.description,
        'prefill': <String, String>{
          'contact': _checkout.contact,
          'email': _checkout.email,
          'name': _checkout.name,
        },
        'theme': <String, String>{'color': '#E4132B'},
        'retry': <String, dynamic>{'enabled': true, 'max_count': 3},
        'timeout': 600,
      });
    } catch (_) {
      setState(() {
        _opening = false;
        _error = 'Could not open the payment sheet. Please try again.';
      });
    }
  }

  Future<void> _onSuccess(PaymentSuccessResponse r) async {
    if (!mounted) return;
    setState(() {
      _opening = false;
      _confirming = true;
      _error = null;
    });
    try {
      final Order paid = await AppScope.of(context).orders.confirmPayment(
            PaymentProof(
              razorpayOrderId: r.orderId ?? _checkout.razorpayOrderId,
              razorpayPaymentId: r.paymentId ?? '',
              razorpaySignature: r.signature ?? '',
            ),
          );
      if (!mounted) return;
      AppScope.of(context).cart.clear();
      AppNavigator.toOrderConfirmation(context, paid);
    } on AppException catch (e) {
      // The money may already be with Razorpay; the server reconciles it.
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  void _onError(PaymentFailureResponse r) {
    if (!mounted) return;
    final String message = switch (r.code) {
      Razorpay.PAYMENT_CANCELLED => 'Payment was cancelled. Your order is saved — you can pay any time.',
      Razorpay.NETWORK_ERROR => 'Network error during payment. Please try again.',
      _ => r.message?.isNotEmpty == true ? r.message! : 'Payment failed. Please try again.',
    };
    setState(() {
      _opening = false;
      _error = message;
    });
  }

  void _onExternalWallet(ExternalWalletResponse r) {
    if (!mounted) return;
    setState(() {
      _opening = false;
      _error = 'Complete the payment in ${r.walletName ?? 'your wallet app'}, then reopen this order.';
    });
  }

  Future<void> _retry() async {
    try {
      final PlaceOrderResult fresh =
          await AppScope.of(context).orders.retryPayment(widget.order.id);
      if (!mounted) return;
      if (fresh.checkout != null) _checkout = fresh.checkout!;
      _open();
    } on AppException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, tone: SnackTone.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Order order = widget.order;
    return PopScope(
      canPop: !_confirming,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: SpocartAppBar(
          title: 'Payment',
          actions: [
            AppIconButton(
              icon: Icons.headset_mic_outlined,
              tooltip: 'Help',
              onPressed: () => showHelpSheet(context, about: 'Payment for order ${order.id}'),
            ),
          ],
        ),
        body: ContentWidth(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: _error == null ? AppColors.surface : AppColors.redTint,
                      shape: BoxShape.circle,
                    ),
                    child: _confirming || _opening
                        ? const Padding(
                            padding: EdgeInsets.all(28),
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : Icon(
                            _error == null ? Icons.lock_outline_rounded : Icons.error_outline_rounded,
                            size: 40,
                            color: _error == null ? AppColors.text : AppColors.red,
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  _confirming
                      ? 'Confirming your payment…'
                      : _opening
                          ? 'Opening secure payment…'
                          : _error == null
                              ? 'Pay ${formatInr(order.total)}'
                              : 'Payment not completed',
                  textAlign: TextAlign.center,
                  style: AppTypography.h1,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _error ??
                      'Order ${order.id} · UPI, cards, net banking and wallets via Razorpay.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMuted,
                ),
                const Spacer(),
                if (!_opening && !_confirming) ...[
                  PrimaryButton(
                    label: _error == null ? 'Pay ${formatInr(order.total)}' : 'Try Again',
                    icon: Icons.lock_outline_rounded,
                    onPressed: _error == null ? _open : _retry,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryButton(
                    label: 'Pay Later from My Orders',
                    color: AppColors.black,
                    onPressed: () => AppNavigator.backToHome(context, tab: HomeTab.orders),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
