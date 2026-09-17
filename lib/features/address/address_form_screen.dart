import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
// SPOCART — Add / edit address
//------------------------------------------------------------------------------
// Pops with the saved Address, or null when cancelled.
//==============================================================================

class AddressFormScreen extends StatefulWidget {
  const AddressFormScreen({super.key, this.existing});

  final Address? existing;

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _contact;
  late final TextEditingController _business;
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _city;
  late final TextEditingController _pincode;
  late final TextEditingController _mobile;
  String? _state;
  AddressLabel _label = AddressLabel.home;
  bool _default = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final Address? a = widget.existing;
    final BusinessProfile? profile = AppScope.of(context).session.session?.profile;
    _contact = TextEditingController(text: a?.contactName ?? profile?.contactName ?? '');
    _business = TextEditingController(text: a?.businessName ?? profile?.businessName ?? '');
    _line1 = TextEditingController(text: a?.line1 ?? '');
    _line2 = TextEditingController(text: a?.line2 ?? '');
    _city = TextEditingController(text: a?.city ?? '');
    _pincode = TextEditingController(text: a?.pincode ?? '');
    _mobile = TextEditingController(
        text: a?.mobile ?? profile?.mobile ?? AppScope.of(context).session.session?.mobile ?? '');
    _state = a?.state;
    _label = a?.label ?? AddressLabel.home;
    _default = a?.isDefault ?? false;
  }

  @override
  void dispose() {
    _contact.dispose();
    _business.dispose();
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _pincode.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final Address address = Address(
        id: widget.existing?.id ?? Ids.local(),
        contactName: _contact.text.trim(),
        businessName: _business.text.trim(),
        line1: _line1.text.trim(),
        line2: _line2.text.trim(),
        city: _city.text.trim(),
        state: _state!,
        pincode: _pincode.text.trim(),
        mobile: _mobile.text.trim(),
        label: _label,
        isDefault: _default,
      );
      final Address saved = await AppScope.of(context).addresses.save(address);
      if (!mounted) return;
      showAppSnackBar(
        context,
        _isEdit ? 'Address updated' : 'Address added',
        tone: SnackTone.success,
      );
      Navigator.of(context).pop(saved);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not save the address.',
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
      appBar: SpocartAppBar(title: _isEdit ? 'Edit Address' : 'Add New Address'),
      body: KeyboardDismisser(
        child: ContentWidth(
          child: Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page, AppSpacing.xs, AppSpacing.page, AppSpacing.xl),
              children: [
                AppTextField(
                  controller: _contact,
                  label: 'Contact Person',
                  required: true,
                  hint: 'Who receives the delivery',
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      Validators.minLength(v, 2, field: 'Contact name'),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _business,
                  label: 'Business / Institution Name',
                  hint: 'Optional',
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _mobile,
                  label: 'Mobile Number',
                  required: true,
                  prefixText: '+91  ',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: Validators.mobile,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _line1,
                  label: 'Address Line 1',
                  required: true,
                  hint: 'Shop no., building, street',
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.streetAddressLine1],
                  validator: (v) =>
                      Validators.minLength(v, 4, field: 'Address'),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _line2,
                  label: 'Address Line 2',
                  hint: 'Area, landmark (optional)',
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.streetAddressLine2],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: AppTextField(
                        controller: _city,
                        label: 'City',
                        required: true,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.addressCity],
                        validator: (v) =>
                            Validators.required(v, field: 'City'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        controller: _pincode,
                        label: 'PIN Code',
                        required: true,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.postalCode],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        validator: Validators.pincode,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppDropdownField<String>(
                  label: 'State',
                  required: true,
                  hint: 'Select state',
                  value: _state,
                  items: kIndianStates,
                  labelOf: (s) => s,
                  onChanged: (s) => setState(() => _state = s),
                  validator: (s) => s == null ? 'Select your state' : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                const FieldLabel(label: 'Save as'),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final AddressLabel l in AddressLabel.values)
                      ChoiceChip(
                        label: Text(l.label),
                        selected: _label == l,
                        onSelected: (_) => setState(() => _label = l),
                        selectedColor: AppColors.black,
                        showCheckmark: false,
                        labelStyle: AppTypography.smallStrong.copyWith(
                          color: _label == l ? AppColors.white : AppColors.text,
                        ),
                        side: BorderSide(
                          color: _label == l ? AppColors.black : AppColors.border,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile.adaptive(
                  value: _default,
                  onChanged: (v) => setState(() => _default = v),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.white,
                  activeTrackColor: AppColors.red,
                  title: const Text('Set as default address',
                      style: AppTypography.body),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: PrimaryButton(
          label: _isEdit ? 'Save Changes' : 'Save Address',
          loading: _saving,
          onPressed: _save,
        ),
      ),
    );
  }
}
