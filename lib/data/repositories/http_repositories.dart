import '../../core/network/api_client.dart';
import '../local/local_store.dart';
import '../models/account.dart';
import '../models/catalog.dart';
import '../models/engagement.dart';
import '../models/order.dart';
import 'repositories.dart';

//==============================================================================
// SPOCART — HTTP repositories (the real backend)
//------------------------------------------------------------------------------
// Thin adapters over ApiClient. Each method is one API call and one
// fromJson; every business rule lives on the server.
//==============================================================================

List<Map<String, dynamic>> _list(dynamic data) =>
    (data as List<dynamic>? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

Map<String, dynamic> _map(dynamic data) =>
    Map<String, dynamic>.from(data as Map);

class HttpCatalogRepository implements CatalogRepository {
  HttpCatalogRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<ProductCategory>> fetchCategories() async =>
      _list(await _api.get('/catalog/categories'))
          .map(ProductCategory.fromJson)
          .toList();

  @override
  Future<List<Product>> fetchProducts() async =>
      _list(await _api.get('/catalog/products')).map(Product.fromJson).toList();
}

class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._api, this._store);

  static const String _tokenKey = 'auth.token';

  final ApiClient _api;
  final LocalStore _store;

  @override
  Future<OtpChallenge> sendOtp(String mobile) async {
    final Map<String, dynamic> d =
        _map(await _api.post('/auth/otp/send', {'mobile': mobile}));
    return OtpChallenge(
      mobile: d['mobile'] as String? ?? mobile,
      expiresAt: DateTime.tryParse(d['expiresAt'] as String? ?? '') ??
          DateTime.now().add(const Duration(minutes: 5)),
    );
  }

  @override
  Future<UserSession> verifyOtp(String mobile, String code) async {
    final Map<String, dynamic> d = _map(
        await _api.post('/auth/otp/verify', {'mobile': mobile, 'code': code}));
    final String token = d['token'] as String;
    final UserSession session = UserSession.fromJson(_map(d['user']));
    _api.token = token;
    await _store.writeStrings(_tokenKey, <String>[token]);
    await _store.writeJson(StoreKeys.session, session.toJson());
    return session;
  }

  @override
  Future<UserSession?> restoreSession() async {
    final List<String>? saved = await _store.readStrings(_tokenKey);
    final Map<String, dynamic>? json = await _store.readMap(StoreKeys.session);
    if (saved == null || saved.isEmpty || json == null) return null;
    _api.token = saved.first;
    try {
      return UserSession.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<UserSession?> refreshSession() async {
    if (_api.token == null) return null;
    try {
      final UserSession session = UserSession.fromJson(_map(await _api.get('/auth/me')));
      await _store.writeJson(StoreKeys.session, session.toJson());
      return session;
    } on AppException {
      // Offline or server hiccup: keep the cached session; a 401 clears it
      // through ApiClient.onUnauthorized.
      return _api.token == null ? null : restoreSession();
    }
  }

  @override
  Future<UserSession> saveProfile(BusinessProfile profile) async {
    final UserSession session = UserSession.fromJson(
        _map(await _api.put('/auth/profile', profile.toJson())));
    await _store.writeJson(StoreKeys.session, session.toJson());
    return session;
  }

  @override
  Future<void> signOut() async {
    _api.token = null;
    await _store.remove(_tokenKey);
    await _store.remove(StoreKeys.session);
  }
}

class HttpOrderRepository implements OrderRepository {
  HttpOrderRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Order>> fetchOrders() async =>
      _list(await _api.get('/orders')).map(Order.fromJson).toList();

  PlaceOrderResult _result(dynamic data) {
    final Map<String, dynamic> d = _map(data);
    return PlaceOrderResult(
      order: Order.fromJson(_map(d['order'])),
      checkout: d['checkout'] == null
          ? null
          : CheckoutSession.fromJson(_map(d['checkout'])),
    );
  }

  @override
  Future<PlaceOrderResult> placeOrder(OrderRequest request) async =>
      _result(await _api.post('/orders', {
        'lines': [
          for (final CartLine l in request.lines)
            {
              'productId': l.productId,
              'quantity': l.quantity,
              if (l.size != null) 'size': l.size,
            },
        ],
        'addressId': request.addressId,
        'paymentMethod': request.paymentMethod.apiName,
      }));

  @override
  Future<Order> verifyPayment(PaymentProof proof) async =>
      Order.fromJson(_map(await _api.post('/orders/payments/verify', proof.toJson())));

  @override
  Future<PlaceOrderResult> retryPayment(String orderId) async =>
      _result(await _api.post('/orders/$orderId/retry-payment'));

  @override
  Future<List<Invoice>> fetchInvoices() async =>
      _list(await _api.get('/invoices')).map(Invoice.fromJson).toList();

  @override
  Future<DashboardStats> fetchDashboard({required double creditLimit}) async =>
      DashboardStats.fromJson(_map(await _api.get('/dashboard')));
}

class HttpAddressRepository implements AddressRepository {
  HttpAddressRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Address>> fetchAddresses() async =>
      _list(await _api.get('/addresses')).map(Address.fromJson).toList();

  @override
  Future<Address> save(Address address) async {
    final Map<String, dynamic> body = address.toJson()..remove('id');
    final bool isNew = address.id.startsWith('local-');
    final dynamic data = isNew
        ? await _api.post('/addresses', body)
        : await _api.put('/addresses/${address.id}', body);
    return Address.fromJson(_map(data));
  }

  @override
  Future<void> remove(String id) => _api.delete('/addresses/$id');

  @override
  Future<void> setDefault(String id) => _api.post('/addresses/$id/default');
}

class HttpTeamRepository implements TeamRepository {
  HttpTeamRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<TeamMember>> fetchMembers() async =>
      _list(await _api.get('/team')).map(TeamMember.fromJson).toList();

  @override
  Future<TeamMember> add(TeamMember member) async => TeamMember.fromJson(
      _map(await _api.post('/team', member.toJson()..remove('id'))));

  @override
  Future<void> remove(String id) => _api.delete('/team/$id');
}

class HttpNotificationRepository implements NotificationRepository {
  HttpNotificationRepository(this._api);

  final ApiClient _api;

  @override
  Future<NotificationPage> fetchAll() async {
    final Map<String, dynamic> d = _map(await _api.get('/notifications'));
    return NotificationPage(
      items: _list(d['items']).map(AppNotification.fromJson).toList(),
      unreadCount: (d['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> push(AppNotification notification) async {}

  @override
  Future<void> markRead(String id) => _api.post('/notifications/$id/read');

  @override
  Future<void> markAllRead() => _api.post('/notifications/read-all');

  @override
  Future<void> clearAll() => _api.delete('/notifications');
}

class HttpQuoteRepository implements QuoteRepository {
  HttpQuoteRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<QuoteRequest>> fetchAll() async =>
      _list(await _api.get('/quotes')).map(QuoteRequest.fromJson).toList();

  @override
  Future<QuoteRequest> submit(QuoteDraft draft) async {
    String? designUrl;
    if (draft.designFilePath != null) {
      final Map<String, dynamic> up = _map(await _api.upload(
        '/uploads/design',
        field: 'file',
        filePath: draft.designFilePath!,
        fileName: draft.designFileName,
      ));
      designUrl = up['path'] as String? ?? up['url'] as String?;
    }
    return QuoteRequest.fromJson(_map(await _api.post('/quotes', {
      'kind': draft.kind.name,
      'items': draft.items.map((i) => i.toJson()..removeWhere((_, v) => v == null)).toList(),
      'notes': draft.notes,
      'designFileUrl': ?designUrl,
    })));
  }
}
