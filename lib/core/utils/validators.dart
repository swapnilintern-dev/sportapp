//==============================================================================
// SPOCART — Form validators
//------------------------------------------------------------------------------
// Each returns null when valid, otherwise a short user-facing message. They are
// composed by the registration, address and manual-order forms.
//==============================================================================

abstract final class Validators {
  static final RegExp _gstin = RegExp(
    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
  );
  static final RegExp _email = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
  static final RegExp _pincode = RegExp(r'^[1-9][0-9]{5}$');
  static final RegExp _mobile = RegExp(r'^[6-9][0-9]{9}$');

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? mobile(String? value) {
    final String digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Mobile number is required';
    if (!_mobile.hasMatch(digits)) return 'Enter a valid 10-digit mobile number';
    return null;
  }

  static String? email(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'Email address is required';
    if (!_email.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? gstin(String? value) {
    final String v = (value ?? '').trim().toUpperCase();
    if (v.isEmpty) return 'GST number is required';
    if (v.length != 15) return 'GSTIN must be 15 characters';
    if (!_gstin.hasMatch(v)) return 'Enter a valid GSTIN (e.g. 20AACCA1234F1Z5)';
    return null;
  }

  static String? pincode(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'PIN code is required';
    if (!_pincode.hasMatch(v)) return 'Enter a valid 6-digit PIN code';
    return null;
  }

  static String? otp(String? value) {
    final String v = (value ?? '').trim();
    if (v.length != 6 || int.tryParse(v) == null) return 'Enter the 6-digit OTP';
    return null;
  }

  static String? minLength(String? value, int min, {String field = 'This'}) {
    final String v = (value ?? '').trim();
    if (v.length < min) return '$field must be at least $min characters';
    return null;
  }

  static String? quantity(String? value, {int min = 1}) {
    final int? q = int.tryParse((value ?? '').trim());
    if (q == null) return 'Enter a quantity';
    if (q < min) return 'Minimum $min';
    return null;
  }
}
