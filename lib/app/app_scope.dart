import 'package:flutter/widgets.dart';

import '../data/local/local_store.dart';
import '../data/repositories/repositories.dart';
import '../state/address_controller.dart';
import '../state/cart_controller.dart';
import '../state/catalog_controller.dart';
import '../state/notifications_controller.dart';
import '../state/orders_controller.dart';
import '../state/quotes_controller.dart';
import '../state/session_controller.dart';
import '../state/settings_controller.dart';
import '../state/team_controller.dart';

//==============================================================================
// SPOCART — Composition root
//------------------------------------------------------------------------------
// AppServices builds every repository + controller once; AppScope exposes them
// to the widget tree. Screens read `AppScope.of(context).cart` etc. and rebuild
// through ListenableBuilder on the controller they care about — no global
// rebuilds, no external state package.
//
// Swap the Demo* repositories here when the SPOCART API is available.
//==============================================================================

/// Bottom navigation destinations of the Home shell, in display order.
enum HomeTab { home, categories, cart, orders, account }

class AppServices {
  AppServices._({
    required this.store,
    required this.session,
    required this.catalog,
    required this.cart,
    required this.wishlist,
    required this.orders,
    required this.addresses,
    required this.notifications,
    required this.quotes,
    required this.settings,
    required this.team,
  });

  factory AppServices.demo(LocalStore store) {
    final AccountKey account = AccountKey();
    final CatalogController catalog =
        CatalogController(const DemoCatalogRepository());
    final CartStorage cartStorage = CartStorage(store);
    final NotificationsController notifications = NotificationsController(
      DemoNotificationRepository(store, account),
    );
    return AppServices._(
      store: store,
      session: SessionController(DemoAuthRepository(store, account)),
      catalog: catalog,
      cart: CartController(cartStorage, catalog),
      wishlist: WishlistController(cartStorage),
      orders: OrdersController(
        DemoOrderRepository(store, account),
        notifications,
      ),
      addresses: AddressController(DemoAddressRepository(store, account)),
      notifications: notifications,
      quotes: QuotesController(
        DemoQuoteRepository(store, account),
        notifications,
      ),
      settings: SettingsController(store),
      team: TeamController(DemoTeamRepository(store, account)),
    );
  }

  final LocalStore store;

  /// The bottom-navigation tab the Home shell should show. Deep screens
  /// ("Continue Shopping", "View Orders") set it before popping to the root.
  final ValueNotifier<HomeTab> homeTab = ValueNotifier<HomeTab>(HomeTab.home);

  final SessionController session;
  final CatalogController catalog;
  final CartController cart;
  final WishlistController wishlist;
  final OrdersController orders;
  final AddressController addresses;
  final NotificationsController notifications;
  final QuotesController quotes;
  final SettingsController settings;
  final TeamController team;

  /// Restores everything that must be known before the first screen draws.
  Future<void> bootstrap() async {
    await Future.wait<void>(<Future<void>>[
      session.restore(),
      cart.load(),
      wishlist.load(),
      settings.load(),
    ]);
  }

  /// Signs out and clears every per-account controller. Account data stays on
  /// the device under its own namespace, so signing back in restores it; the
  /// cart and wishlist are device-local shopping state and are kept.
  Future<void> signOut() async {
    await session.signOut();
    orders.reset();
    addresses.reset();
    notifications.reset();
    quotes.reset();
    team.reset();
  }

  void dispose() {
    homeTab.dispose();
    session.dispose();
    catalog.dispose();
    cart.dispose();
    wishlist.dispose();
    orders.dispose();
    addresses.dispose();
    notifications.dispose();
    quotes.dispose();
    settings.dispose();
    team.dispose();
  }
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final AppScope? scope =
        context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope was not found above this widget.');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      oldWidget.services != services;
}
