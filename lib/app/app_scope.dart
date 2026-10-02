import 'package:flutter/widgets.dart';

import '../core/network/api_client.dart';
import '../data/local/local_store.dart';
import '../data/repositories/http_repositories.dart';
import '../data/repositories/repositories.dart';
import '../state/address_controller.dart';
import '../state/cart_controller.dart';
import '../state/catalog_controller.dart';
import '../state/notifications_controller.dart';
import '../state/orders_controller.dart';
import '../state/promotion_controller.dart';
import '../state/reviews_controller.dart';
import '../state/rewards_controller.dart';
import '../state/quotes_controller.dart';
import '../state/session_controller.dart';
import '../state/settings_controller.dart';
import '../state/team_controller.dart';

//==============================================================================
// SPOCART — Composition root
//------------------------------------------------------------------------------
// AppServices builds every repository + controller once; AppScope exposes them
// to the widget tree. `AppServices.http` talks to the SPOCART API (default);
// `AppServices.demo` runs fully on-device for tests and offline reviews.
//==============================================================================

/// Bottom navigation destinations of the Home shell, in display order.
enum HomeTab { home, categories, cart, orders, account }

class AppServices {
  AppServices._({
    required this.store,
    required this.isDemo,
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
    required this.promotions,
    required this.reviews,
    required this.rewards,
    this.api,
  });


  /// Real backend: PostgreSQL + Razorpay through the SPOCART API.
  factory AppServices.http(LocalStore store, {ApiClient? client}) {
    final ApiClient api = client ?? ApiClient();
    final HttpCatalogRepository catalogRepository = HttpCatalogRepository(api);
    final CatalogController catalog = CatalogController(catalogRepository);
    final CartStorage cartStorage = CartStorage(store);
    final NotificationsController notifications =
        NotificationsController(HttpNotificationRepository(api));
    final AppServices services = AppServices._(
      store: store,
      isDemo: false,
      api: api,
      session: SessionController(HttpAuthRepository(api, store)),
      catalog: catalog,
      cart: CartController(cartStorage, catalog),
      wishlist: WishlistController(cartStorage),
      orders: OrdersController(HttpOrderRepository(api), notifications),
      addresses: AddressController(HttpAddressRepository(api)),
      notifications: notifications,
      quotes: QuotesController(HttpQuoteRepository(api), notifications),
      settings: SettingsController(store),
      team: TeamController(HttpTeamRepository(api)),
      promotions: PromotionController(catalogRepository, store),
      reviews: ReviewsController(HttpReviewRepository(api)),
      rewards: RewardsController(HttpRewardRepository(api)),
    );
    // A 401 means the token is dead server-side: drop the session and let the
    // app fall back to Login.
    api.onUnauthorized = () {
      services.session.signOut();
      services._resetAccountState();
      services.sessionExpired.value = services.sessionExpired.value + 1;
    };
    return services;
  }

  /// On-device demo backend (no server, no Razorpay).
  factory AppServices.demo(LocalStore store) {
    final AccountKey account = AccountKey();
    const DemoCatalogRepository catalogRepository = DemoCatalogRepository();
    final CatalogController catalog = CatalogController(catalogRepository);
    final CartStorage cartStorage = CartStorage(store);
    final NotificationsController notifications = NotificationsController(
      DemoNotificationRepository(store, account),
      localEvents: true,
    );
    return AppServices._(
      store: store,
      isDemo: true,
      session: SessionController(DemoAuthRepository(store, account)),
      catalog: catalog,
      cart: CartController(cartStorage, catalog),
      wishlist: WishlistController(cartStorage),
      orders: OrdersController(DemoOrderRepository(store, account), notifications),
      addresses: AddressController(DemoAddressRepository(store, account)),
      notifications: notifications,
      quotes: QuotesController(DemoQuoteRepository(store, account), notifications),
      settings: SettingsController(store),
      team: TeamController(DemoTeamRepository(store, account)),
      promotions: PromotionController(catalogRepository, store),
      reviews: ReviewsController(DemoReviewRepository(store, account)),
      rewards: RewardsController(const DemoRewardRepository()),
    );
  }

  final LocalStore store;
  final bool isDemo;

  /// The HTTP client (null in demo mode).
  final ApiClient? api;

  /// The bottom-navigation tab the Home shell should show.
  final ValueNotifier<HomeTab> homeTab = ValueNotifier<HomeTab>(HomeTab.home);

  /// Bumped when the server rejects the session; the app root listens and
  /// returns to Login.
  final ValueNotifier<int> sessionExpired = ValueNotifier<int>(0);

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
  final PromotionController promotions;
  final ReviewsController reviews;
  final RewardsController rewards;

  /// Restores everything that must be known before the first screen draws.
  Future<void> bootstrap() async {
    await Future.wait<void>(<Future<void>>[
      session.restore(),
      cart.load(),
      wishlist.load(),
      settings.load(),
    ]);
  }

  /// Signs out and clears every per-account controller. Cart and wishlist are
  /// device-local shopping state and are kept.
  Future<void> signOut() async {
    await session.signOut();
    _resetAccountState();
  }

  void _resetAccountState() {
    orders.reset();
    addresses.reset();
    notifications.reset();
    quotes.reset();
    team.reset();
    // A promotion can target registered or unregistered buyers, so the next
    // sign-in must ask again rather than reuse the previous buyer's offer.
    promotions.reset();
    reviews.reset();
    rewards.reset();
  }

  void dispose() {
    homeTab.dispose();
    sessionExpired.dispose();
    session.dispose();
    catalog.dispose();
    cart.dispose();
    wishlist.dispose();
    orders.dispose();
    addresses.dispose();
    promotions.dispose();
    reviews.dispose();
    rewards.dispose();
    notifications.dispose();
    quotes.dispose();
    settings.dispose();
    team.dispose();
    api?.close();
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
