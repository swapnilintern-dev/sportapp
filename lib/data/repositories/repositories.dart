import 'dart:math';

import '../local/local_store.dart';
import '../models/account.dart';
import '../models/catalog.dart';
import '../models/engagement.dart';
import '../models/order.dart';
import '../sources/demo_catalog.dart';

//==============================================================================
// SPOCART — Repositories (the backend seam)
//------------------------------------------------------------------------------
// Screens and controllers only ever talk to these abstract repositories. The
// `Demo*` implementations below run entirely on-device (in-memory catalogue +
// LocalStore persistence) because the SPOCART API does not exist yet.
//
// To connect the real backend: implement each interface over HTTP and swap the
// constructors in lib/app/app_services.dart. Nothing above this layer changes.
//
// Every demo call awaits a short latency so loading states are real, and every
// failure surfaces as [AppException] with a user-safe message.
//==============================================================================

class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<void> _latency([int ms = 350]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

/// Identifies whose data the per-account repositories read and write. Set by
/// the session layer on sign-in; keys are namespaced so two buyers signing in
/// on the same device never see each other's orders or addresses.
class AccountKey {
  String? mobile;

  String scoped(String key) => '${mobile ?? 'guest'}:$key';
}

//------------------------------------------------------------------------------
// Catalogue
//------------------------------------------------------------------------------
abstract class CatalogRepository {
  Future<List<ProductCategory>> fetchCategories();
  Future<List<Product>> fetchProducts();
}

class DemoCatalogRepository implements CatalogRepository {
  const DemoCatalogRepository();

  @override
  Future<List<ProductCategory>> fetchCategories() async {
    await _latency(250);
    return kDemoCategories;
  }

  @override
  Future<List<Product>> fetchProducts() async {
    await _latency(450);
    return kDemoProducts;
  }
}

//------------------------------------------------------------------------------
// Authentication (mobile OTP)
//------------------------------------------------------------------------------
class OtpChallenge {
  const OtpChallenge({
    required this.mobile,
    required this.expiresAt,
    this.demoCode,
  });

  final String mobile;
  final DateTime expiresAt;

  /// Only set by the demo backend, which has no SMS gateway. The OTP screen
  /// shows it so the flow can be completed on-device. Null with a real API.
  final String? demoCode;
}

abstract class AuthRepository {
  Future<OtpChallenge> sendOtp(String mobile);
  Future<UserSession> verifyOtp(String mobile, String code);
  Future<UserSession?> restoreSession();
  Future<void> saveSession(UserSession session);
  Future<void> signOut();
}

class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository(this._store, this._account);

  final LocalStore _store;
  final AccountKey _account;
  final Random _random = Random();
  final Map<String, String> _pendingCodes = <String, String>{};

  @override
  Future<OtpChallenge> sendOtp(String mobile) async {
    await _latency(600);
    final String code =
        (100000 + _random.nextInt(900000)).toString();
    _pendingCodes[mobile] = code;
    return OtpChallenge(
      mobile: mobile,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      demoCode: code,
    );
  }

  @override
  Future<UserSession> verifyOtp(String mobile, String code) async {
    await _latency(700);
    final String? expected = _pendingCodes[mobile];
    if (expected == null) {
      throw const AppException('This OTP has expired. Please request a new one.');
    }
    if (expected != code) {
      throw const AppException('Incorrect OTP. Please check and try again.');
    }
    _pendingCodes.remove(mobile);

    // A returning buyer keeps their business profile.
    final UserSession? previous = await restoreSession();
    final UserSession session = UserSession(
      mobile: mobile,
      signedInAt: DateTime.now(),
      profile: previous?.mobile == mobile ? previous?.profile : null,
      creditLimit: previous?.creditLimit ?? 100000,
    );
    await saveSession(session);
    return session;
  }

  @override
  Future<UserSession?> restoreSession() async {
    final Map<String, dynamic>? json = await _store.readMap(StoreKeys.session);
    if (json == null) return null;
    try {
      final UserSession session = UserSession.fromJson(json);
      _account.mobile = session.mobile;
      return session;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveSession(UserSession session) {
    _account.mobile = session.mobile;
    return _store.writeJson(StoreKeys.session, session.toJson());
  }

  @override
  Future<void> signOut() {
    _account.mobile = null;
    return _store.remove(StoreKeys.session);
  }
}

//------------------------------------------------------------------------------
// Orders & invoices
//------------------------------------------------------------------------------
abstract class OrderRepository {
  Future<List<Order>> fetchOrders();
  Future<Order> placeOrder(Order draft);
  Future<void> saveAll(List<Order> orders);
}

class DemoOrderRepository implements OrderRepository {
  DemoOrderRepository(this._store, this._account);

  final LocalStore _store;
  final AccountKey _account;

  String get _key => _account.scoped(StoreKeys.orders);

  /// Demo fulfilment: with no warehouse system behind the app, an order moves
  /// through the pipeline on a compressed clock so tracking has something to
  /// show. Replace with server-driven status when the API lands.
  static const List<Duration> _stageAfter = <Duration>[
    Duration.zero, // placed
    Duration(minutes: 3), // packed
    Duration(minutes: 15), // dispatched
    Duration(hours: 2), // out for delivery
    Duration(hours: 8), // delivered
  ];

  @override
  Future<List<Order>> fetchOrders() async {
    await _latency(400);
    final List<Map<String, dynamic>>? raw = await _store.readList(_key);
    if (raw == null) return const <Order>[];
    final List<Order> orders = <Order>[];
    for (final Map<String, dynamic> json in raw) {
      try {
        orders.add(_advance(Order.fromJson(json)));
      } catch (_) {
        // Skip a corrupt entry rather than losing the whole history.
      }
    }
    orders.sort((a, b) => b.placedAt.compareTo(a.placedAt));
    return orders;
  }

  Order _advance(Order order) {
    if (order.status == OrderStatus.cancelled) return order;
    final Duration elapsed = DateTime.now().difference(order.placedAt);
    int stage = 0;
    for (int i = 0; i < _stageAfter.length; i++) {
      if (elapsed >= _stageAfter[i]) stage = i;
    }
    final OrderStatus derived = kTrackingSteps[stage];
    if (derived.index <= order.status.index) return order;
    return order.copyWith(
      status: derived,
      statusUpdatedAt: order.placedAt.add(_stageAfter[stage]),
    );
  }

  @override
  Future<Order> placeOrder(Order draft) async {
    await _latency(900);
    final List<Map<String, dynamic>> raw =
        await _store.readList(_key) ?? <Map<String, dynamic>>[];
    raw.insert(0, draft.toJson());
    await _store.writeJson(_key, raw);
    return draft;
  }

  @override
  Future<void> saveAll(List<Order> orders) =>
      _store.writeJson(_key, orders.map((o) => o.toJson()).toList());
}

//------------------------------------------------------------------------------
// Addresses
//------------------------------------------------------------------------------
abstract class AddressRepository {
  Future<List<Address>> fetchAddresses();
  Future<void> saveAll(List<Address> addresses);
}

class DemoAddressRepository implements AddressRepository {
  DemoAddressRepository(this._store, this._account);

  final LocalStore _store;
  final AccountKey _account;

  String get _key => _account.scoped(StoreKeys.addresses);

  @override
  Future<List<Address>> fetchAddresses() async {
    await _latency(250);
    final List<Map<String, dynamic>>? raw = await _store.readList(_key);
    if (raw == null) return const <Address>[];
    return raw.map(Address.fromJson).toList();
  }

  @override
  Future<void> saveAll(List<Address> addresses) =>
      _store.writeJson(_key, addresses.map((a) => a.toJson()).toList());
}

//------------------------------------------------------------------------------
// Team members
//------------------------------------------------------------------------------
abstract class TeamRepository {
  Future<List<TeamMember>> fetchMembers();
  Future<void> saveAll(List<TeamMember> members);
}

class DemoTeamRepository implements TeamRepository {
  DemoTeamRepository(this._store, this._account);

  final LocalStore _store;
  final AccountKey _account;

  String get _key => _account.scoped(StoreKeys.team);

  @override
  Future<List<TeamMember>> fetchMembers() async {
    await _latency(250);
    final List<Map<String, dynamic>>? raw = await _store.readList(_key);
    if (raw == null) return const <TeamMember>[];
    return raw.map(TeamMember.fromJson).toList();
  }

  @override
  Future<void> saveAll(List<TeamMember> members) =>
      _store.writeJson(_key, members.map((m) => m.toJson()).toList());
}

//------------------------------------------------------------------------------
// Notifications
//------------------------------------------------------------------------------
abstract class NotificationRepository {
  Future<List<AppNotification>> fetchAll();
  Future<void> saveAll(List<AppNotification> items);
}

class DemoNotificationRepository implements NotificationRepository {
  DemoNotificationRepository(this._store, this._account);

  final LocalStore _store;
  final AccountKey _account;

  String get _key => _account.scoped(StoreKeys.notifications);

  @override
  Future<List<AppNotification>> fetchAll() async {
    await _latency(250);
    final List<Map<String, dynamic>>? raw = await _store.readList(_key);
    if (raw == null) return const <AppNotification>[];
    return raw.map(AppNotification.fromJson).toList();
  }

  @override
  Future<void> saveAll(List<AppNotification> items) =>
      _store.writeJson(_key, items.map((n) => n.toJson()).toList());
}

//------------------------------------------------------------------------------
// Quotations
//------------------------------------------------------------------------------
abstract class QuoteRepository {
  Future<List<QuoteRequest>> fetchAll();
  Future<QuoteRequest> submit(QuoteRequest draft);
  Future<void> saveAll(List<QuoteRequest> items);
}

class DemoQuoteRepository implements QuoteRepository {
  DemoQuoteRepository(this._store, this._account);

  final LocalStore _store;
  final AccountKey _account;

  String get _key => _account.scoped(StoreKeys.quotes);

  @override
  Future<List<QuoteRequest>> fetchAll() async {
    await _latency(300);
    final List<Map<String, dynamic>>? raw = await _store.readList(_key);
    if (raw == null) return const <QuoteRequest>[];
    final List<QuoteRequest> quotes = raw.map(QuoteRequest.fromJson).toList();
    quotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return quotes;
  }

  @override
  Future<QuoteRequest> submit(QuoteRequest draft) async {
    await _latency(800);
    final List<Map<String, dynamic>> raw =
        await _store.readList(_key) ?? <Map<String, dynamic>>[];
    raw.insert(0, draft.toJson());
    await _store.writeJson(_key, raw);
    return draft;
  }

  @override
  Future<void> saveAll(List<QuoteRequest> items) =>
      _store.writeJson(_key, items.map((q) => q.toJson()).toList());
}

//------------------------------------------------------------------------------
// Cart & wishlist persistence (pure local state, no server round-trip)
//------------------------------------------------------------------------------
class CartStorage {
  CartStorage(this._store);

  final LocalStore _store;

  Future<List<CartLine>> load() async {
    final List<Map<String, dynamic>>? raw = await _store.readList(StoreKeys.cart);
    if (raw == null) return const <CartLine>[];
    return raw.map(CartLine.fromJson).toList();
  }

  Future<void> save(List<CartLine> lines) =>
      _store.writeJson(StoreKeys.cart, lines.map((l) => l.toJson()).toList());

  Future<List<String>> loadWishlist() async =>
      await _store.readStrings(StoreKeys.wishlist) ?? const <String>[];

  Future<void> saveWishlist(List<String> ids) =>
      _store.writeStrings(StoreKeys.wishlist, ids);
}

//------------------------------------------------------------------------------
// Id generation
//------------------------------------------------------------------------------
abstract final class Ids {
  static final Random _random = Random();

  static String _seq() => (1000 + _random.nextInt(9000)).toString();

  /// SC-2025-0345
  static String order(DateTime now) => 'SC-${now.year}-${_seq()}';

  /// INV-2025-0132
  static String invoice(DateTime now) => 'INV-${now.year}-${_seq()}';

  /// QT-2025-0871
  static String quote(DateTime now) => 'QT-${now.year}-${_seq()}';

  /// Opaque local id for addresses / notifications.
  static String local() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 20)}';
}
