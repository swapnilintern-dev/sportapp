//==============================================================================
// SPOCART — App-wide constants
//==============================================================================

abstract final class AppInfo {
  static const String name = 'SPOCART';
  static const String tagline = 'Your Sports Business Partner';
  static const String version = '1.0.0';
  static const String website = 'https://www.spocart.info';

  // These three are submitted to the Play Console and App Store Connect, so
  // the URLs must keep working once an app build is live. Do not repoint them
  // without updating the store listings as well.
  static const String privacyUrl = 'https://www.spocart.info/privacy.html';
  static const String termsUrl = 'https://www.spocart.info/terms.html';

  /// The public page Google Play requires: how to close an account without the
  /// app installed. The in-app route lives in Account → Privacy & Security.
  static const String deleteAccountUrl =
      'https://www.spocart.info/delete-account.html';
}

/// Business contact points surfaced on the help sheet and support screens.
abstract final class SupportContacts {
  static const String phoneDisplay = '+91 70619 11575';
  static const String phoneDial = '+917061911575';
  static const String whatsappNumber = '917061911575';
  static const String email = 'sales@spocart.in';
  static const String hours = 'Mon–Sat, 10:00 am – 7:00 pm IST';
}

/// Business rules.
abstract final class BusinessRules {
  static const double gstRate = 0.18;
  static const int otpLength = 6;
  /// Matches the server's own resend cooldown; a shorter button would just
  /// earn a "please wait" error.
  static const Duration otpResendCooldown = Duration(seconds: 60);
  static const double defaultCreditLimit = 100000;
}
