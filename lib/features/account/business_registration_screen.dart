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
import '../../data/models/account.dart';
import '../../data/repositories/repositories.dart';

//==============================================================================
// SPOCART — Business registration ("Complete Your Business Details")
//------------------------------------------------------------------------------
// Shown after the cart, before the first checkout. Also reused as the
// Business Details editor from the account screens (allowSkip = false).
// Pops with true when saved, false when skipped / cancelled.
//==============================================================================

class BusinessRegistrationScreen extends StatefulWidget {
  const BusinessRegistrationScreen({
    super.key,
    this.allowSkip = true,
    this.title = 'Complete Your Business Details',
    this.subtitle =
        'To place the order, we need a few details about your business.',
  });

  final bool allowSkip;
  final String title;
  final String subtitle;

  @override
  State<BusinessRegistrationScreen> createState() =>
      _BusinessRegistrationScreenState();
}

class _BusinessRegistrationScreenState
    extends State<BusinessRegistrationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _businessName;
  late final TextEditingController _gstin;
  late final TextEditingController _contactName;
  late final TextEditingController _mobile;
  late final TextEditingController _email;
  BusinessType? _type;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final UserSession? session = AppScope.of(context).session.session;
    final BusinessProfile? p = session?.profile;
    _businessName = TextEditingController(text: p?.businessName ?? '');
    _gstin = TextEditingController(text: p?.gstin ?? '');
    _contactName = TextEditingController(text: p?.contactName ?? '');
    _mobile = TextEditingController(text: p?.mobile ?? session?.mobile ?? '');
    _email = TextEditingController(text: p?.email ?? '');
    _type = p?.businessType;
  }

  @override
  void dispose() {
    _businessName.dispose();
    _gstin.dispose();
    _contactName.dispose();
    _mobile.dispose();
    _email.dispose();
    super.dispose();
  }

  /// The number is verified by OTP on its own screen; when that succeeds the
  /// session carries the new number, so the field just re-reads it.
  Future<void> _changeMobile(BuildContext context) async {
    final bool changed = await AppNavigator.toChangeMobile(context) ?? false;
    if (!changed || !mounted) return;
    setState(() {
      _mobile.text = AppScope.of(context).session.session?.mobile ?? _mobile.text;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await AppScope.of(context).session.saveProfile(
            BusinessProfile(
              businessName: _businessName.text.trim(),
              gstin: _gstin.text.trim().toUpperCase(),
              businessType: _type!,
              contactName: _contactName.text.trim(),
              // The server stores the account's verified number regardless;
              // this keeps the demo backend in step.
              mobile: _mobile.text.trim(),
              email: _email.text.trim(),
            ),
          );
      if (!mounted) return;
      showAppSnackBar(context, 'Business details saved.',
          tone: SnackTone.success);
      Navigator.of(context).pop(true);
    } on AppException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, tone: SnackTone.error);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not save. Please try again.',
            tone: SnackTone.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SpocartAppBar(
        onBack: () => Navigator.of(context).pop(false),
      ),
      body: KeyboardDismisser(
        child: ContentWidth(
          child: Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
              children: [
                Text(widget.title, style: AppTypography.h1),
                const SizedBox(height: AppSpacing.xs),
                Text(widget.subtitle, style: AppTypography.bodyMuted),
                const SizedBox(height: AppSpacing.xl),
                AppTextField(
                  controller: _businessName,
                  label: 'Business Name',
                  required: true,
                  hint: 'Enter business name',
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.organizationName],
                  validator: (v) => Validators.minLength(v, 2,
                      field: 'Business name'),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _gstin,
                  label: 'GST Number',
                  required: true,
                  hint: 'Enter GST number',
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 15,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                    _UpperCaseFormatter(),
                  ],
                  validator: Validators.gstin,
                ),
                const SizedBox(height: AppSpacing.md),
                AppDropdownField<BusinessType>(
                  label: 'Business Type',
                  required: true,
                  hint: 'Select business type',
                  value: _type,
                  items: BusinessType.values,
                  labelOf: (t) => t.label,
                  onChanged: (t) => setState(() => _type = t),
                  validator: (t) =>
                      t == null ? 'Select your business type' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _contactName,
                  label: 'Contact Person',
                  required: true,
                  hint: 'Enter your name',
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  validator: (v) =>
                      Validators.minLength(v, 2, field: 'Contact name'),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _mobile,
                  label: 'Mobile Number',
                  prefixText: '+91  ',
                  readOnly: true,
                  helper: 'Your verified sign-in number.',
                  suffix: GhostButton(
                    label: 'Change',
                    onPressed: () => _changeMobile(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _email,
                  label: 'Email Address',
                  required: true,
                  hint: 'Enter email address',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: widget.allowSkip ? 'Continue' : 'Save Details',
                  loading: _saving,
                  onPressed: _save,
                ),
                if (widget.allowSkip) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: GhostButton(
                      label: 'Skip for now',
                      color: AppColors.textSoft,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
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

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
