import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';

//==============================================================================
// SPOCART — UPI payment
//------------------------------------------------------------------------------
// Renders a standard UPI intent QR (any UPI app can scan it), offers "Pay with
// UPI app" (opens the upi:// intent on the device) and the UPI ID with copy.
// "Payment Done" resolves true after the buyer confirms they have paid —
// server-side reconciliation is a backend concern, so the confirmation is
// explicit and the order records the transaction reference.
//==============================================================================

class UpiPaymentScreen extends StatefulWidget {
  const UpiPaymentScreen({
    super.key,
    required this.amount,
    required this.reference,
  });

  final double amount;
  final String reference;

  @override
  State<UpiPaymentScreen> createState() => _UpiPaymentScreenState();
}

class _UpiPaymentScreenState extends State<UpiPaymentScreen> {
  bool _confirming = false;

  Uri get _intent => Uri(
        scheme: 'upi',
        host: 'pay',
        queryParameters: <String, String>{
          'pa': PaymentDetails.upiId,
          'pn': PaymentDetails.payeeName,
          'am': widget.amount.toStringAsFixed(2),
          'cu': 'INR',
          'tn': widget.reference,
        },
      );

  Future<void> _openUpiApp() async {
    bool ok = false;
    try {
      ok = await launchUrl(_intent, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      showAppSnackBar(
        context,
        'No UPI app found. Scan the QR from another device or use the UPI ID.',
        tone: SnackTone.error,
      );
    }
  }

  Future<void> _copyUpiId() async {
    await Clipboard.setData(const ClipboardData(text: PaymentDetails.upiId));
    if (mounted) {
      showAppSnackBar(context, 'UPI ID copied', tone: SnackTone.success);
    }
  }

  Future<void> _confirmPaid() async {
    if (_confirming) return;
    final bool ok = await showAppConfirmDialog(
      context,
      title: 'Confirm payment',
      message:
          'Have you completed the UPI payment of ${formatInr(widget.amount)} to ${PaymentDetails.upiId}? Your order will be placed and verified against the transaction.',
      confirmLabel: 'Yes, Paid',
      icon: Icons.verified_outlined,
    );
    if (!ok || !mounted) return;
    setState(() => _confirming = true);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_confirming,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const SpocartAppBar(title: 'UPI Payment'),
        body: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              const _UpiAppsRow(),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Scan & Pay with any UPI app',
                textAlign: TextAlign.center,
                style: AppTypography.h3,
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: AppRadius.lgAll,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: QrImageView(
                    data: _intent.toString(),
                    size: 200,
                    backgroundColor: AppColors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AppColors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Pay ${formatInr(widget.amount)}',
                textAlign: TextAlign.center,
                style: AppTypography.priceLarge,
              ),
              Text(
                'Ref: ${widget.reference}',
                textAlign: TextAlign.center,
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.lg),
              SecondaryButton(
                label: 'Pay with UPI App',
                icon: Icons.open_in_new_rounded,
                color: AppColors.black,
                onPressed: _openUpiApp,
              ),
              const SizedBox(height: AppSpacing.lg),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Text('Or use UPI ID', style: AppTypography.caption),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(PaymentDetails.upiId,
                          style: AppTypography.bodyStrong),
                    ),
                    GhostButton(
                      label: 'Copy',
                      icon: Icons.copy_rounded,
                      onPressed: _copyUpiId,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'After paying, tap "Payment Done". Our team verifies the '
                'transaction before dispatch; the GST invoice is issued on '
                'confirmation.',
                style: AppTypography.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomActionBar(
          child: PrimaryButton(
            label: 'Payment Done',
            icon: Icons.check_circle_outline_rounded,
            loading: _confirming,
            onPressed: _confirmPaid,
          ),
        ),
      ),
    );
  }
}

class _UpiAppsRow extends StatelessWidget {
  const _UpiAppsRow();

  static const List<(String, IconData, Color)> _apps = <(String, IconData, Color)>[
    ('BHIM', Icons.account_balance_rounded, Color(0xFF1B5E20)),
    ('PhonePe', Icons.phone_android_rounded, Color(0xFF5F259F)),
    ('Paytm', Icons.wallet_rounded, Color(0xFF00BAF2)),
    ('GPay', Icons.g_mobiledata_rounded, Color(0xFF4285F4)),
    ('Any UPI', Icons.qr_code_scanner_rounded, AppColors.black),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final (String name, IconData icon, Color color) in _apps)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 4),
              Text(name, style: AppTypography.caption),
            ],
          ),
      ],
    );
  }
}
