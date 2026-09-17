import 'package:flutter/material.dart';

import '../data/models/account.dart';
import '../data/models/catalog.dart';
import '../data/models/order.dart';
import '../features/account/account_screens.dart';
import '../features/account/business_registration_screen.dart';
import '../features/account/dashboard_screen.dart';
import '../features/account/settings_screen.dart';
import '../features/address/address_form_screen.dart';
import '../features/address/addresses_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/bulk_upload/bulk_upload_screen.dart';
import '../features/catalog/bulk_pricing_screen.dart';
import '../features/catalog/product_details_screen.dart';
import '../features/catalog/product_list_screen.dart';
import '../features/catalog/search_screen.dart';
import '../features/checkout/checkout_screen.dart';
import '../features/checkout/order_confirmation_screen.dart';
import '../features/checkout/razorpay_checkout_screen.dart';
import '../features/custom_order/custom_order_screen.dart';
import '../features/home/home_shell.dart';
import '../features/invoices/invoices_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/orders/order_details_screen.dart';
import '../features/quotes/quotes_screen.dart';
import '../features/wishlist/wishlist_screen.dart';
import 'app_scope.dart';

//==============================================================================
// SPOCART — Navigation
//------------------------------------------------------------------------------
// Every route in the app is opened through these typed helpers, so there are
// no string route names to mistype and no screen can be orphaned: if it isn't
// reachable from here, it isn't in the app.
//
// MaterialPageRoute adapts its transition per platform (slide-from-right and
// swipe-back on iOS, fade-through on Android).
//==============================================================================

abstract final class AppNavigator {
  static Future<T?> _push<T>(BuildContext context, Widget screen,
      {bool fullscreenDialog = false}) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute<T>(
        builder: (_) => screen,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  // ─── Auth ──────────────────────────────────────────────────────────────────
  static void toLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  static Future<void> toOtp(BuildContext context) =>
      _push<void>(context, const OtpScreen());

  // ─── Home shell ────────────────────────────────────────────────────────────
  /// Replaces the whole stack with the Home shell on [tab].
  static void toHome(BuildContext context, {HomeTab tab = HomeTab.home}) {
    AppScope.of(context).homeTab.value = tab;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeShell()),
      (_) => false,
    );
  }

  /// Pops every pushed screen and switches the Home shell to [tab].
  static void backToHome(BuildContext context, {HomeTab tab = HomeTab.home}) {
    AppScope.of(context).homeTab.value = tab;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ─── Catalogue ─────────────────────────────────────────────────────────────
  static Future<void> toCategory(BuildContext context, ProductCategory category) =>
      _push<void>(context, ProductListScreen(category: category));

  static Future<void> toProduct(BuildContext context, Product product) =>
      _push<void>(context, ProductDetailsScreen(product: product));

  static Future<void> toProductById(BuildContext context, String productId) async {
    final Product? product = AppScope.of(context).catalog.productById(productId);
    if (product == null) return;
    return toProduct(context, product);
  }

  static Future<void> toBulkPricing(BuildContext context, Product product) =>
      _push<void>(context, BulkPricingScreen(product: product));

  static Future<void> toSearch(BuildContext context, {String? initialQuery}) =>
      _push<void>(context, SearchScreen(initialQuery: initialQuery));

  static Future<void> toWishlist(BuildContext context) =>
      _push<void>(context, const WishlistScreen());

  // ─── Buying ────────────────────────────────────────────────────────────────
  /// Opens registration; resolves true when the profile was saved.
  static Future<bool> toBusinessRegistration(BuildContext context,
      {bool allowSkip = true}) async {
    final bool? saved = await _push<bool>(
      context,
      BusinessRegistrationScreen(allowSkip: allowSkip),
    );
    return saved ?? false;
  }

  static Future<void> toCheckout(BuildContext context) =>
      _push<void>(context, const CheckoutScreen());

  /// Razorpay checkout for an order the API created in paymentPending.
  static void toRazorpayCheckout(BuildContext context,
      {required Order order, required CheckoutSession checkout}) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => RazorpayCheckoutScreen(order: order, checkout: checkout),
      ),
    );
  }

  static void toOrderConfirmation(BuildContext context, Order order) {
    // Replace checkout + payment so back never returns into a paid flow.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => OrderConfirmationScreen(order: order),
      ),
      (route) => route.isFirst,
    );
  }

  // ─── Orders ────────────────────────────────────────────────────────────────
  static Future<void> toOrderDetails(BuildContext context, String orderId) =>
      _push<void>(context, OrderDetailsScreen(orderId: orderId));

  static Future<void> toInvoices(BuildContext context) =>
      _push<void>(context, const InvoicesScreen());

  static Future<void> toQuotes(BuildContext context) =>
      _push<void>(context, const QuotesScreen());

  // ─── Account ───────────────────────────────────────────────────────────────
  static Future<void> toAddresses(BuildContext context) =>
      _push<void>(context, const AddressesScreen());

  /// Address form; resolves with the saved address or null when cancelled.
  static Future<Address?> toAddressForm(BuildContext context,
      {Address? existing}) =>
      _push<Address>(context, AddressFormScreen(existing: existing),
          fullscreenDialog: true);

  static Future<void> toBusinessDetails(BuildContext context) =>
      _push<void>(context, const BusinessDetailsScreen());

  static Future<void> toGstDetails(BuildContext context) =>
      _push<void>(context, const GstDetailsScreen());

  static Future<void> toTeamMembers(BuildContext context) =>
      _push<void>(context, const TeamMembersScreen());

  static Future<void> toDashboard(BuildContext context) =>
      _push<void>(context, const DashboardScreen());

  static Future<void> toNotifications(BuildContext context) =>
      _push<void>(context, const NotificationsScreen());

  static Future<void> toSettings(BuildContext context) =>
      _push<void>(context, const SettingsScreen());

  static Future<void> toNotificationSettings(BuildContext context) =>
      _push<void>(context, const NotificationSettingsScreen());

  static Future<void> toPrivacySecurity(BuildContext context) =>
      _push<void>(context, const PrivacySecurityScreen());

  static Future<void> toHelpSupport(BuildContext context) =>
      _push<void>(context, const HelpSupportScreen());

  static Future<void> toAbout(BuildContext context) =>
      _push<void>(context, const AboutScreen());

  // ─── Bulk & custom ─────────────────────────────────────────────────────────
  static Future<void> toCustomOrder(BuildContext context) =>
      _push<void>(context, const CustomOrderScreen());

  static Future<void> toBulkUpload(BuildContext context) =>
      _push<void>(context, const BulkUploadScreen());
}
