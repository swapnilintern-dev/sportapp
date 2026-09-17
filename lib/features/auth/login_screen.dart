import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_navigator.dart';
import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../data/repositories/repositories.dart';
import '../support/help_sheet.dart';

//==============================================================================
// SPOCART — Login (mobile number)
//------------------------------------------------------------------------------
// Step 1 of the direct OTP login: capture the mobile number and request a
// one-time code. Step 2 is OtpScreen.
//==============================================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _mobile = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_submitting) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      await AppScope.of(context).session.sendOtp(_mobile.text.trim());
      if (!mounted) return;
      await AppNavigator.toOtp(context);
    } on AppException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, tone: SnackTone.error);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Could not send the OTP. Please check your connection.',
          tone: SnackTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: KeyboardDismisser(
        child: SafeArea(
          child: ContentWidth(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.lg,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - AppSpacing.lg * 2,
                  ),
                  child: IntrinsicHeight(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppSpacing.xxl),
                          const Center(child: BrandLogo(height: 88)),
                          const SizedBox(height: AppSpacing.xxxl),
                          const Text(
                            'Login with Mobile Number',
                            style: AppTypography.h1,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'We’ll send a 6-digit OTP to verify your number. '
                            'No password needed.',
                            style: AppTypography.bodyMuted,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          AppTextField(
                            controller: _mobile,
                            label: 'Mobile Number',
                            required: true,
                            hint: '98765 43210',
                            prefixText: '+91  ',
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            autofocus: true,
                            autofillHints: const [
                              AutofillHints.telephoneNumber,
                            ],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            validator: Validators.mobile,
                            onSubmitted: (_) => _sendOtp(),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          PrimaryButton(
                            label: 'Send OTP',
                            loading: _submitting,
                            onPressed: _sendOtp,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'By continuing you agree to SPOCART’s Terms of '
                            'Service and Privacy Policy.',
                            textAlign: TextAlign.center,
                            style: AppTypography.caption,
                          ),
                          const Spacer(),
                          const SizedBox(height: AppSpacing.xxl),
                          Center(
                            child: GhostButton(
                              label: 'Having trouble? Contact Support',
                              icon: Icons.headset_mic_outlined,
                              color: AppColors.textSoft,
                              onPressed: () => showHelpSheet(
                                context,
                                title: 'Need help signing in?',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
