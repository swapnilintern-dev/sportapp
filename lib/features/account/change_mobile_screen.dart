import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/inputs.dart';
import '../../core/widgets/layout.dart';
import '../../data/repositories/repositories.dart';
import '../../state/session_controller.dart';

//==============================================================================
// SPOCART — Change registered mobile number
//------------------------------------------------------------------------------
// Two steps: enter the new number, then the code sent to it. The number is only
// written once the server has verified that code, and the server signs the
// buyer's other devices out at the same time. Backing out of step 2 cancels the
// request, so a half-finished change never leaves anything behind.
//==============================================================================

class ChangeMobileScreen extends StatefulWidget {
  const ChangeMobileScreen({super.key});

  @override
  State<ChangeMobileScreen> createState() => _ChangeMobileScreenState();
}

class _ChangeMobileScreenState extends State<ChangeMobileScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _mobile = TextEditingController();
  final TextEditingController _code = TextEditingController();

  bool _sending = false;
  bool _verifying = false;
  bool _codeWrong = false;

  Timer? _ticker;
  int _secondsLeft = 0;

  SessionController get _session => AppScope.of(context).session;
  bool get _awaitingCode => _session.mobileChangeChallenge != null;

  @override
  void dispose() {
    _ticker?.cancel();
    _mobile.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _ticker?.cancel();
    setState(() => _secondsLeft = BusinessRules.otpResendCooldown.inSeconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) return timer.cancel();
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _send({bool resend = false}) async {
    if (_sending) return;
    if (!resend && !(_form.currentState?.validate() ?? false)) return;
    if (resend && _secondsLeft > 0) return;

    setState(() => _sending = true);
    try {
      await _session.requestMobileChange(_mobile.text.trim());
      if (!mounted) return;
      _code.clear();
      _startCooldown();
      setState(() => _codeWrong = false);
      showAppSnackBar(
        context,
        'OTP sent to +91 ${_mobile.text.trim()}',
        tone: SnackTone.success,
      );
    } on AppException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, tone: SnackTone.error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    if (_verifying) return;
    final String code = _code.text.trim();
    if (Validators.otp(code) != null) {
      setState(() => _codeWrong = true);
      return;
    }
    setState(() {
      _verifying = true;
      _codeWrong = false;
    });
    try {
      final String changedTo = _session.mobileChangeChallenge?.mobile ?? '';
      await _session.confirmMobileChange(code);
      if (!mounted) return;
      // The messenger lives above this route, so the snackbar outlives the pop.
      showAppSnackBar(
        context,
        'Your number is now +91 $changedTo. Other devices have been signed out.',
        tone: SnackTone.success,
        duration: const Duration(seconds: 5),
      );
      Navigator.of(context).pop(true);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _codeWrong = true);
      showAppSnackBar(context, e.message, tone: SnackTone.error);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _editNumber() {
    _session.cancelMobileChange();
    _ticker?.cancel();
    setState(() {
      _secondsLeft = 0;
      _codeWrong = false;
    });
    _code.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final String current = _session.session?.mobile ?? '';
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: const SpocartAppBar(title: 'Change Mobile Number'),
          body: ContentWidth(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                AppCard(
                  color: AppColors.surface,
                  borderColor: AppColors.surface,
                  child: Row(
                    children: [
                      const Icon(Icons.phone_iphone_rounded,
                          color: AppColors.textSoft),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Current number',
                                style: AppTypography.caption),
                            Text('+91 $current',
                                style: AppTypography.bodyStrong),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (!_awaitingCode) ..._numberStep() else ..._codeStep(),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _numberStep() => <Widget>[
        Form(
          key: _form,
          child: AppTextField(
            controller: _mobile,
            label: 'New mobile number',
            required: true,
            prefixText: '+91 ',
            hint: '10-digit number',
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            validator: Validators.mobile,
            autofillHints: const <String>[AutofillHints.telephoneNumber],
            onSubmitted: (_) => _send(),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'We will send a 6-digit OTP to this number. Your number changes only '
          'after you enter that OTP. You will stay signed in here; your other '
          'devices will be signed out.',
          style: AppTypography.small.copyWith(color: AppColors.textSoft),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Send OTP',
          loading: _sending,
          onPressed: _sending ? null : _send,
        ),
      ];

  List<Widget> _codeStep() {
    final String target = _session.mobileChangeChallenge?.mobile ?? '';
    final String? demoCode = _session.mobileChangeChallenge?.demoCode;
    return <Widget>[
      Row(
        children: [
          Expanded(
            child: Text('Enter the OTP sent to +91 $target',
                style: AppTypography.bodyStrong),
          ),
          GhostButton(label: 'Change', onPressed: _editNumber),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      OtpInput(
        controller: _code,
        hasError: _codeWrong,
        enabled: !_verifying,
        onCompleted: (_) => _verify(),
      ),
      if (demoCode != null) ...[
        const SizedBox(height: AppSpacing.sm),
        Text('SMS is not connected on this build — the OTP is $demoCode',
            style: AppTypography.caption, textAlign: TextAlign.center),
      ],
      const SizedBox(height: AppSpacing.lg),
      PrimaryButton(
        label: 'Verify & Save',
        loading: _verifying,
        onPressed: _verifying ? null : _verify,
      ),
      const SizedBox(height: AppSpacing.sm),
      Center(
        child: _secondsLeft > 0
            ? Text(
                'Resend OTP in 00:${_secondsLeft.toString().padLeft(2, '0')}',
                style: AppTypography.small.copyWith(color: AppColors.textSoft),
              )
            : GhostButton(
                label: _sending ? 'Sending…' : 'Resend OTP',
                onPressed: _sending ? null : () => _send(resend: true),
              ),
      ),
    ];
  }
}
