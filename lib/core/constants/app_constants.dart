//==============================================================================
// SPOCART — App-wide constants
//==============================================================================

abstract final class AppInfo {
  static const String name = 'SPOCART';
  static const String tagline = 'Your Sports Business Partner';
  static const String version = '1.0.0';
  static const String website = 'https://spocart.in';
  static const String privacyUrl = 'https://spocart.in/about.html';
  static const String termsUrl = 'https://spocart.in/about.html';
}

/// Business contact points surfaced on the help sheet and support screens.
abstract final class SupportContacts {
  static const String phoneDisplay = '+91 70619 11575';
  static const String phoneDial = '+917061911575';
  static const String whatsappNumber = '917061911575';
  static const String email = 'sales@spocart.in';
  static const String hours = 'Mon–Sat, 10:00 am – 7:00 pm IST';
}

/// Collection details shown on the UPI payment screen.
abstract final class PaymentDetails {
  static const String upiId = 'spocart@okaxis';
  static const String payeeName = 'SPOCART';
}

/// Business rules.
abstract final class BusinessRules {
  static const double gstRate = 0.18;
  static const int otpLength = 6;
  static const Duration otpResendCooldown = Duration(seconds: 45);
  static const double defaultCreditLimit = 100000;
}
