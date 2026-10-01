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
// Controllers only ever talk to these abstract repositories. Two
// implementations exist for each:
//
//   • Http*  (lib/data/repositories/http_repositories.dart) — the SPOCART API
//     on PostgreSQL + Razorpay. Used by default.
//   • Demo*  (this file) — fully on-device, no server. Used by the widget
//     tests and when the app runs with --dart-define=USE_DEMO_BACKEND=true.
//
// Every failure surfaces as [AppException] with a user-safe message.
//==============================================================================

class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<void> _latency([int ms = 350]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

/// Identifies whose data the per-account demo repositories read and write.
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

  /// Only set by the demo backend, which has no SMS gateway. Null with the API.
  final String? demoCode;
}

abstract class AuthRepository {
  Future<OtpChallenge> sendOtp(String mobile);
  Future<UserSession> verifyOtp(String mobile, String code);

  /// The cached session from the last sign-in, or null. Never hits the network.
  Future<UserSession?> restoreSession();

  /// Fresh copy of the session from the server (profile, credit limit).
  /// Returns null when the session is no longer valid.
  Future<UserSession?> refreshSession();

  Future<UserSession> saveProfile(BusinessProfile profile);

  /// Sends a code to [newMobile] so the account can be moved to it. The number
  /// is not changed yet — [confirmMobileChange] does that.
  Future<OtpChallenge> requestMobileChange(String newMobile);

  /// Verifies the code sent to [newMobile] and returns the updated session.
  /// Other devices are signed out by the server.
  Future<UserSession> confirmMobileChange(String newMobile, String code);

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
    final String code = (100000 + _random.nextInt(900000)).toString();
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

    final UserSession? previous = await restoreSession();
    final UserSession session = UserSession(
      mobile: mobile,
      signedInAt: DateTime.now(),
      profile: previous?.mobile == mobile ? previous?.profile : null,
      creditLimit: previous?.creditLimit ?? 100000,
    );
    await _save(session);
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
  Future<UserSession?> refreshSession() => restoreSession();

  @override
  Future<UserSession> saveProfile(BusinessProfile profile) async {
    await _latency(400);
    final UserSession? current = await restoreSession();
    if (current == null) throw const AppException('You are not signed in.');
    final UserSession updated = current.copyWith(profile: profile);
    await _save(updated);
    return updated;
  }

  @override
  Future<OtpChallenge> requestMobileChange(String newMobile) async {
    final UserSession? current = await restoreSession();
    if (current == null) throw const AppException('You are not signed in.');
    if (current.mobile == newMobile) {
      throw const AppException('That is already your registered number.');
    }
    await _latency(600);
    final String code = (100000 + _random.nextInt(900000)).toString();
    _pendingCodes['change:$newMobile'] = code;
    return OtpChallenge(
      mobile: newMobile,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      demoCode: code,
    );
  }

  @override
  Future<UserSession> confirmMobileChange(String newMobile, String code) async {
    await _latency(700);
    final String? expected = _pendingCodes['change:$newMobile'];
    if (expected == null) {
      throw const AppException('This OTP has expired. Please request a new one.');
    }
    if (expected != code) {
      throw const AppException('Incorrect OTP. Please check and try again.');
    }
    _pendingCodes.remove('change:$newMobile');

    final UserSession? current = await restoreSession();
    if (current == null) throw const AppException('You are not signed in.');
    // Demo data is stored per mobile number; the API keys everything by user
    // id, so only the demo backend has to carry it across.
    await _moveScopedData(current.mobile, newMobile);
    final UserSession updated = current.copyWith(
      mobile: newMobile,
      profile: current.profile?.copyWith(mobile: newMobile),
    );
    await _save(updated);
    return updated;
  }

  Future<void> _moveScopedData(String from, String to) async {
    if (from == to) return;
    for (final String key in StoreKeys.scoped) {
      final String oldKey = '$from:$key';
      final List<Map<String, dynamic>>? list = await _store.readList(oldKey);
      if (list != null) {
        await _store.writeJson('$to:$key', list);
      } else {
        final Map<String, dynamic>? map = await _store.readMap(oldKey);
        if (map != null) {
          await _store.writeJson('$to:$key', map);
        } else {
          final List<String>? strings = await _store.readStrings(oldKey);
          if (strings == null) continue;
          await _store.writeJson('$to:$key', strings);
        }
      }
      await _store.remove(oldKey);
    }
  }

  Future<void> _save(UserSession session) {
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
// Orders, payments, invoices, dashboard
//------------------------------------------------------------------------------

/// What the app sends to place an order. [snapshot] is the fully priced order
/// the cart produced; the API re-prices from [lines] and ignores the totals.
class OrderRequest {
  const OrderRequest({
    required this.snapshot,
    required this.lines,
    required this.addressId,
    required this.paymentMethod,
  });

  final Order snapshot;
  final List<CartLine> lines;
  final String addressId;
  final PaymentMethod paymentMethod;
}

abstract class OrderRepository {
  Future<List<Order>> fetchOrders();
  Future<PlaceOrderResult> placeOrder(OrderRequest request);

  /// Confirms a Razorpay checkout; returns the paid order.
  Future<Order> verifyPayment(PaymentProof proof);

  /// A fresh checkout for an order still awaiting payment.
  Future<PlaceOrderResult> retryPayment(String orderId);

  Future<List<Invoice>> fetchInvoices();
  Future<DashboardStats> fetchDashboard({required double creditLimit});
}

class DemoOrderRepository implements OrderRepository {
  DemoOrderRepository(this._store, this._account);

  final LocalStore _store;
  final AccountKey _account;

  String get _key => _account.scoped(StoreKeys.orders);

  /// Demo fulfilment: with no warehouse behind the app, an order moves through
  /// the pipeline on a compressed clock so tracking has something to show.
  static const List<Duration> _stageAfter = <Duration>[
    Duration.zero,
    Duration(minutes: 3),
    Duration(minutes: 15),
    Duration(hours: 2),
    Duration(hours: 8),
  ];

  @override
  Future<List<Order>> fetchOrders() async {
    await _latency(400);
    return _load();
  }

  Future<List<Order>> _load() async {
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
    if (order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.paymentPending) {
      return order;
    }
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
  Future<PlaceOrderResult> placeOrder(OrderRequest request) async {
    await _latency(900);
    // No gateway in demo mode: online orders are treated as paid on the spot.
    final bool credit = request.paymentMethod == PaymentMethod.payLater;
    final Order order =
        request.snapshot.copyWith(status: OrderStatus.placed, paid: !credit);
    final List<Map<String, dynamic>> raw =
        await _store.readList(_key) ?? <Map<String, dynamic>>[];
    raw.insert(0, order.toJson());
    await _store.writeJson(_key, raw);
    return PlaceOrderResult(order: order);
  }

  @override
  Future<Order> verifyPayment(PaymentProof proof) async {
    throw const AppException('Online payment needs the SPOCART server.');
  }

  @override
  Future<PlaceOrderResult> retryPayment(String orderId) async {
    throw const AppException('Online payment needs the SPOCART server.');
  }

  @override
  Future<List<Invoice>> fetchInvoices() async {
    final List<Order> orders = await _load();
    return orders
        .where((o) => o.status != OrderStatus.cancelled)
        .map((o) => Invoice(
              id: o.invoiceId,
              orderId: o.id,
              date: o.placedAt,
              amount: o.total,
              paid: o.paid,
            ))
        .toList(growable: false);
  }

  @override
  Future<DashboardStats> fetchDashboard({required double creditLimit}) async {
    final List<Order> orders = await _load();
    final List<Order> live =
        orders.where((o) => o.status != OrderStatus.cancelled).toList();
    final double outstanding = live
        .where((o) => !o.paid)
        .fold(0, (sum, o) => sum + o.total);
    final Set<String> seen = <String>{};
    int repeats = 0;
    for (final Order o in live.reversed) {
      if (o.lines.any((l) => seen.contains(l.productId))) repeats++;
      seen.addAll(o.lines.map((l) => l.productId));
    }
    final List<Map<String, dynamic>>? quotes =
        await _store.readList(_account.scoped(StoreKeys.quotes));
    return DashboardStats(
      totalPurchases: live.fold(0, (sum, o) => sum + o.total),
      pendingOrders: live.where((o) => o.status.isOpen).length,
      outstandingPayment: outstanding,
      savedQuotations: quotes?.length ?? 0,
      repeatOrders: repeats,
      availableCredit: (creditLimit - outstanding).clamp(0, creditLimit),
      creditLimit: creditLimit,
    );
  }
}

//------------------------------------------------------------------------------
// Addresses
//------------------------------------------------------------------------------
/// City and state behind an Indian PIN code, as the server resolved it.
class PincodeLocation {
  const PincodeLocation({
    required this.pincode,
    required this.city,
    required this.district,
    required this.state,
  });

  final String pincode;
  final String city;
  final String district;
  final String state;

  factory PincodeLocation.fromJson(Map<String, dynamic> json) => PincodeLocation(
        pincode: json['pincode'] as String,
        city: json['city'] as String? ?? '',
        district: json['district'] as String? ?? '',
        state: json['state'] as String? ?? '',
      );
}

abstract class AddressRepository {
  Future<List<Address>> fetchAddresses();

  /// Creates (new id) or updates (existing id). Returns the saved row.
  Future<Address> save(Address address);
  Future<void> remove(String id);
  Future<void> setDefault(String id);

  /// Resolves [pincode] to a city and state. Throws an [AppException] when the
  /// PIN is unknown or the lookup is unavailable — the form then lets the buyer
  /// type both fields, so this never blocks saving an address.
  Future<PincodeLocation> lookupPincode(String pincode);
}

class DemoAddressRepository implements AddressRepository {
  DemoAddressRepository(this._store, this._account);

  final LocalStore _store;
  final AccountKey _account;

  String get _key => _account.scoped(StoreKeys.addresses);

  Future<List<Address>> _load() async {
    final List<Map<String, dynamic>>? raw = await _store.readList(_key);
    return raw == null ? <Address>[] : raw.map(Address.fromJson).toList();
  }

  Future<void> _write(List<Address> list) =>
      _store.writeJson(_key, list.map((a) => a.toJson()).toList());

  @override
  Future<List<Address>> fetchAddresses() async {
    await _latency(250);
    return _load();
  }

  @override
  Future<Address> save(Address address) async {
    await _latency(300);
    final List<Address> list = await _load();
    final int i = list.indexWhere((a) => a.id == address.id);
    Address next = address;
    if (list.isEmpty) next = next.copyWith(isDefault: true);
    if (next.isDefault) {
      for (int j = 0; j < list.length; j++) {
        list[j] = list[j].copyWith(isDefault: false);
      }
    }
    if (i >= 0) {
      list[i] = next;
    } else {
      list.add(next);
    }
    await _write(list);
    return next;
  }

  @override
  Future<void> remove(String id) async {
    final List<Address> list = await _load();
    final bool wasDefault = list.any((a) => a.id == id && a.isDefault);
    list.removeWhere((a) => a.id == id);
    if (wasDefault && list.isNotEmpty) list[0] = list[0].copyWith(isDefault: true);
    await _write(list);
  }

  @override
  Future<void> setDefault(String id) async {
    final List<Address> list = await _load();
    await _write(list.map((a) => a.copyWith(isDefault: a.id == id)).toList());
  }

  /// The demo backend has no PIN service; it answers for a few PINs so the
  /// autofill can be exercised offline and reports the rest as unavailable.
  @override
  Future<PincodeLocation> lookupPincode(String pincode) async {
    await _latency(350);
    final PincodeLocation? known = kDemoPincodes[pincode];
    if (known == null) {
      throw const AppException(
          'PIN code lookup is unavailable right now. Please type your city and state.');
    }
    return known;
  }
}

/// A handful of real PINs for the offline demo backend.
const Map<String, PincodeLocation> kDemoPincodes = <String, PincodeLocation>{
  '411001': PincodeLocation(
      pincode: '411001', city: 'Pune City', district: 'Pune', state: 'Maharashtra'),
  '110001': PincodeLocation(
      pincode: '110001', city: 'New Delhi', district: 'Central Delhi', state: 'Delhi'),
  '560001': PincodeLocation(
      pincode: '560001', city: 'Bangalore North', district: 'Bangalore', state: 'Karnataka'),
  '700001': PincodeLocation(
      pincode: '700001', city: 'Kolkata', district: 'Kolkata', state: 'West Bengal'),
  '400001': PincodeLocation(
      pincode: '400001', city: 'Mumbai', district: 'Mumbai', state: 'Maharashtra'),
};

//------------------------------------------------------------------------------
// Team members
//------------------------------------------------------------------------------
abstract class TeamRepository {
  Future<List<TeamMember>> fetchMembers();
  Future<TeamMember> add(TeamMember member);
  Future<void> remove(String id);
}

class DemoTeamRepository implements TeamRepository {
  DemoTeamRepository(this._store, this._account);

  final LocalStore _store;
  final AccountKey _account;

  String get _key => _account.scoped(StoreKeys.team);

  Future<List<TeamMember>> _load() async {
    final List<Map<String, dynamic>>? raw = await _store.readList(_key);
    return raw == null ? <TeamMember>[] : raw.map(TeamMember.fromJson).toList();
  }

  Future<void> _write(List<TeamMember> list) =>
      _store.writeJson(_key, list.map((m) => m.toJson()).toList());

  @override
  Future<List<TeamMember>> fetchMembers() async {
    await _latency(250);
    return _load();
  }

  @override
  Future<TeamMember> add(TeamMember member) async {
    final List<TeamMember> list = await _load()
      ..add(member);
    await _write(list);
    return member;
  }

  @override
  Future<void> remove(String id) async {
    final List<TeamMember> list = await _load()
      ..removeWhere((m) => m.id == id);
    await _write(list);
  }
}

//------------------------------------------------------------------------------
// Notifications
//------------------------------------------------------------------------------
class NotificationPage {
  const NotificationPage({required this.items, required this.unreadCount});

  final List<AppNotification> items;
  final int unreadCount;
}

abstract class NotificationRepository {
  Future<NotificationPage> fetchAll();
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<void> clearAll();

  /// Demo only: the server writes notifications; the demo app writes its own.
  Future<void> push(AppNotification notification) async {}
}

class DemoNotificationRepository implements NotificationRepository {
  DemoNotificationRepository(this._store, this._account);

  final LocalStore _store;
  final AccountKey _account;

  String get _key => _account.scoped(StoreKeys.notifications);

  Future<List<AppNotification>> _load() async {
    final List<Map<String, dynamic>>? raw = await _store.readList(_key);
    final List<AppNotification> list =
        raw == null ? <AppNotification>[] : raw.map(AppNotification.fromJson).toList();
    list.sort((a, b) => b.time.compareTo(a.time));
    return list;
  }

  Future<void> _write(List<AppNotification> list) =>
      _store.writeJson(_key, list.map((n) => n.toJson()).toList());

  @override
  Future<NotificationPage> fetchAll() async {
    await _latency(250);
    final List<AppNotification> list = await _load();
    return NotificationPage(
      items: list,
      unreadCount: list.where((n) => !n.read).length,
    );
  }

  @override
  Future<void> push(AppNotification notification) async {
    final List<AppNotification> list = await _load()
      ..insert(0, notification);
    await _write(list);
  }

  @override
  Future<void> markRead(String id) async {
    final List<AppNotification> list = await _load();
    await _write(list.map((n) => n.id == id ? n.copyWith(read: true) : n).toList());
  }

  @override
  Future<void> markAllRead() async {
    final List<AppNotification> list = await _load();
    await _write(list.map((n) => n.copyWith(read: true)).toList());
  }

  @override
  Future<void> clearAll() => _write(<AppNotification>[]);
}

//------------------------------------------------------------------------------
// Quotations
//------------------------------------------------------------------------------
class QuoteDraft {
  const QuoteDraft({
    required this.kind,
    required this.items,
    required this.notes,
    this.designFilePath,
    this.designFileName,
  });

  final QuoteKind kind;
  final List<QuoteItem> items;
  final String notes;

  /// Local path of the artwork picked by the buyer (uploaded by the repo).
  final String? designFilePath;
  final String? designFileName;
}

abstract class QuoteRepository {
  Future<List<QuoteRequest>> fetchAll();
  Future<QuoteRequest> submit(QuoteDraft draft);
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
  Future<QuoteRequest> submit(QuoteDraft draft) async {
    await _latency(800);
    final DateTime now = DateTime.now();
    final QuoteRequest quote = QuoteRequest(
      id: Ids.quote(now),
      kind: draft.kind,
      createdAt: now,
      items: draft.items,
      notes: draft.notes,
      designFileName: draft.designFileName,
    );
    final List<Map<String, dynamic>> raw =
        await _store.readList(_key) ?? <Map<String, dynamic>>[];
    raw.insert(0, quote.toJson());
    await _store.writeJson(_key, raw);
    return quote;
  }
}

//------------------------------------------------------------------------------
// Cart & wishlist persistence (device-local in both modes)
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
// Id generation (demo mode; the API assigns real ids)
//------------------------------------------------------------------------------
abstract final class Ids {
  static final Random _random = Random();

  static String _seq() => (1000 + _random.nextInt(9000)).toString();

  static String order(DateTime now) => 'SC-${now.year}-${_seq()}';
  static String invoice(DateTime now) => 'INV-${now.year}-${_seq()}';
  static String quote(DateTime now) => 'QT-${now.year}-${_seq()}';

  static String local() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 20)}';
}
