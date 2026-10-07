import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_navigator.dart';
import '../../app/app_scope.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../data/models/engagement.dart';
import '../../data/repositories/repositories.dart';
import '../../state/session_controller.dart';
import '../support/help_sheet.dart';

//==============================================================================
// SPOCART — OTP verification
//------------------------------------------------------------------------------
// Six-box code entry with a resend cooldown. On success the buyer lands on
// Home; registration is deferred until they place an order.
//==============================================================================

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _code = TextEditingController();
  Timer? _ticker;
  int _secondsLeft = BusinessRules.otpResendCooldown.inSeconds;
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  SessionController get _session => AppScope.of(context).session;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    _fillCodeIfGiven();
  }

  /// When no SMS can be delivered the server hands the code back, and the app
  /// shows it on screen. Typing out a number the phone already has is busywork,
  /// so fill the boxes — OtpInput verifies as soon as six digits are in, which
  /// makes signing in a single tap on Send OTP.
  ///
  /// A server that really sends an SMS never returns a code, so there is
  /// nothing to fill and the buyer types it as normal.
  void _fillCodeIfGiven() {
    final String? given = _session.challenge?.demoCode;
    if (given == null || given.length != BusinessRules.otpLength) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _code.text.isEmpty) _code.text = given;
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _ticker?.cancel();
    setState(() => _secondsLeft = BusinessRules.otpResendCooldown.inSeconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _verify() async {
    if (_verifying) return;
    final String code = _code.text.trim();
    if (code.length != BusinessRules.otpLength) {
      setState(() => _error = 'Enter the 6-digit OTP');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final AppServices services = AppScope.of(context);
      await services.session.verifyOtp(code);
      // Demo mode: welcome the buyer on their first sign-in on this device.
      await services.notifications.load();
      if (services.notifications.localEvents &&
          services.notifications.items.isEmpty) {
        await services.notifications.pushLocal(
          type: NotificationType.offer,
          title: 'Welcome to SPOCART',
          body:
              'Bulk sports equipment for your business. Browse the catalogue, '
              'add to cart and complete your business details at checkout.',
        );
      }
      if (!mounted) return;
      AppNavigator.toHome(context);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Verification failed. Please try again.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resending || _secondsLeft > 0) return;
    final String? mobile = _session.challenge?.mobile;
    if (mobile == null) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _resending = true;
      _error = null;
      _code.clear();
    });
    try {
      await _session.sendOtp(mobile);
      if (!mounted) return;
      _code.clear();
      _fillCodeIfGiven();
      _startCooldown();
      showAppSnackBar(context, 'A new OTP has been sent.',
          tone: SnackTone.success);
    } on AppException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, tone: SnackTone.error);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not resend the OTP.',
            tone: SnackTone.error);
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final OtpChallenge? challenge = _session.challenge;
        final String mobile = formatIndianMobile(challenge?.mobile ?? '');
        final String cooldown =
            '00:${_secondsLeft.toString().padLeft(2, '0')}';

        return Scaffold(
          backgroundColor: AppColors.white,
          appBar: const SpocartAppBar(backgroundColor: AppColors.white),
          body: KeyboardDismisser(
            child: SafeArea(
              top: false,
              child: ContentWidth(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.md),
                      const Center(child: BrandLogo(height: 80)),
                      const SizedBox(height: AppSpacing.xxl),
                      const Text('Verify Your Mobile Number',
                          style: AppTypography.h1),
                      const SizedBox(height: AppSpacing.xs),
                      Text.rich(
                        TextSpan(
                          text: 'Enter the 6 digit OTP sent to\n',
                          style: AppTypography.bodyMuted,
                          children: [
                            TextSpan(
                              text: mobile,
                              style: AppTypography.bodyStrong,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      OtpInput(
                        controller: _code,
                        enabled: !_verifying,
                        hasError: _error != null,
                        onCompleted: (_) => _verify(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 16, color: AppColors.red),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _error!,
                                style: AppTypography.small
                                    .copyWith(color: AppColors.red),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (challenge?.demoCode != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        _DemoCodeNotice(code: challenge!.demoCode!),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Center(
                        child: _secondsLeft > 0
                            ? Text(
                                'Resend OTP in $cooldown',
                                style: AppTypography.small,
                              )
                            : GhostButton(
                                label: _resending ? 'Sending…' : 'Resend OTP',
                                onPressed: _resending ? null : _resend,
                              ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      PrimaryButton(
                        label: 'Continue',
                        loading: _verifying,
                        onPressed: _verify,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Center(
                        child: GhostButton(
                          label: 'Change number',
                          color: AppColors.textSoft,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
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
        );
      },
    );
  }
}

/// Shown only by the demo backend (no SMS gateway yet) so the flow can be
/// completed on-device. Disappears automatically once a real AuthRepository
/// stops returning a demo code.
class _DemoCodeNotice extends StatelessWidget {
  const _DemoCodeNotice({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined,
              size: 18, color: AppColors.textSoft),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'SMS is not connected on this build. Your OTP is ',
                style: AppTypography.caption,
                children: [
                  TextSpan(
                    text: code,
                    style: AppTypography.smallStrong
                        .copyWith(letterSpacing: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
