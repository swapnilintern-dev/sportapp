import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport/core/network/api_client.dart';
import 'package:sport/data/local/local_store.dart';
import 'package:sport/data/models/account.dart';
import 'package:sport/data/models/catalog.dart';
import 'package:sport/data/models/engagement.dart';
import 'package:sport/data/models/order.dart';
import 'package:sport/data/repositories/http_repositories.dart';
import 'package:sport/data/repositories/repositories.dart';

/// A fake SPOCART API: records requests and answers from a route table.
class FakeApi {
  final List<http.Request> requests = <http.Request>[];
  final Map<String, dynamic Function(http.Request)> routes = {};

  MockClient get client => MockClient((req) async {
        requests.add(req);
        final String key = '${req.method} ${req.url.path}';
        final dynamic Function(http.Request)? handler = routes[key];
        if (handler == null) {
          return http.Response(jsonEncode({'ok': false, 'message': 'Route not found.'}), 404);
        }
        final dynamic body = handler(req);
        if (body is http.Response) return body;
        return http.Response(jsonEncode({'ok': true, 'data': body}), 200,
            headers: {'content-type': 'application/json'});
      });
}

Map<String, dynamic> _orderJson({String status = 'paymentPending'}) => {
      'id': 'SC-2026-0007',
      'placedAt': '2026-09-17T10:00:00.000Z',
      'status': status,
      'paymentMethod': 'razorpay',
      'paid': status != 'paymentPending',
      'subtotal': 24000,
      'gst': 4320,
      'total': 28320,
      'address': {
        'id': 'a1', 'contactName': 'Rohit', 'line1': 'MG Road', 'city': 'Ranchi',
        'state': 'Jharkhand', 'pincode': '834001', 'mobile': '9876543210',
      },
      'invoiceId': 'INV-2026-0007',
      'trackingId': 'SPK1',
      'etaStart': '2026-09-20',
      'etaEnd': '2026-09-24',
      'lines': [
        {'productId': 'fb-match-ball-5', 'name': 'Football', 'image': '', 'unit': 'pc', 'quantity': 20, 'unitPrice': 1200, 'size': '5'},
      ],
      'payment': {'status': 'captured', 'method': 'netbanking'},
    };

void main() {
  late FakeApi fake;
  late ApiClient api;
  late MemoryStore store;

  setUp(() {
    fake = FakeApi();
    api = ApiClient(client: fake.client, baseUrl: 'http://api.test/api/v1');
    store = MemoryStore();
  });

  group('Mobile number change', () {
    Future<HttpAuthRepository> signedIn() async {
      fake.routes['POST /api/v1/auth/otp/send'] =
          (_) => {'mobile': '9876543210', 'expiresAt': '2026-09-17T10:05:00Z'};
      fake.routes['POST /api/v1/auth/otp/verify'] = (_) => {
            'token': 'jwt-old',
            'user': {
              'mobile': '9876543210',
              'signedInAt': '2026-09-17T10:00:00Z',
              'profile': null,
              'creditLimit': 100000,
            },
          };
      final HttpAuthRepository auth = HttpAuthRepository(api, store);
      await auth.sendOtp('9876543210');
      await auth.verifyOtp('9876543210', '123456');
      return auth;
    }

    test('request posts the new number and returns the expiry', () async {
      final HttpAuthRepository auth = await signedIn();
      fake.routes['POST /api/v1/auth/mobile/change/send'] =
          (_) => {'mobile': '9123456780', 'expiresAt': '2026-09-17T10:06:00Z'};

      final OtpChallenge challenge = await auth.requestMobileChange('9123456780');
      expect(challenge.mobile, '9123456780');
      expect(challenge.expiresAt.isAfter(DateTime.utc(2026, 9, 17, 10, 5)), isTrue);
      // Never leaks a code to the client.
      expect(challenge.demoCode, isNull);

      final http.Request sent = fake.requests.last;
      expect(jsonDecode(sent.body), {'mobile': '9123456780'});
      expect(sent.headers['authorization'], 'Bearer jwt-old');
    });

    test('verify swaps in the new token and session', () async {
      final HttpAuthRepository auth = await signedIn();
      fake.routes['POST /api/v1/auth/mobile/change/verify'] = (_) => {
            'token': 'jwt-new',
            'user': {
              'mobile': '9123456780',
              'signedInAt': '2026-09-17T10:07:00Z',
              'profile': null,
              'creditLimit': 100000,
            },
          };

      final UserSession session =
          await auth.confirmMobileChange('9123456780', '654321');
      expect(session.mobile, '9123456780');

      // The old token is gone: later calls carry the new one, and a restart
      // restores the new session.
      fake.routes['GET /api/v1/auth/me'] = (_) => {
            'mobile': '9123456780',
            'signedInAt': '2026-09-17T10:07:00Z',
            'profile': null,
            'creditLimit': 100000,
          };
      await auth.refreshSession();
      expect(fake.requests.last.headers['authorization'], 'Bearer jwt-new');
      expect((await auth.restoreSession())!.mobile, '9123456780');
    });

    test('a rejected code leaves the session on the old number', () async {
      final HttpAuthRepository auth = await signedIn();
      fake.routes['POST /api/v1/auth/mobile/change/verify'] = (_) => http.Response(
          jsonEncode({'ok': false, 'message': 'Incorrect OTP. Please check and try again.'}), 400);

      await expectLater(
        auth.confirmMobileChange('9123456780', '000000'),
        throwsA(isA<AppException>().having(
            (AppException e) => e.message, 'message', contains('Incorrect OTP'))),
      );
      expect((await auth.restoreSession())!.mobile, '9876543210');
    });
  });

  group('Best sellers', () {
    test('parses the ranking and passes the limit', () async {
      fake.routes['GET /api/v1/catalog/best-sellers'] =
          (_) => {'productIds': ['ck-ss-ball', 'fb-match-ball-5']};
      final List<String> ids =
          await HttpCatalogRepository(api).fetchBestSellerIds(limit: 5);
      expect(ids, ['ck-ss-ball', 'fb-match-ball-5']);
      expect(fake.requests.last.url.queryParameters['limit'], '5');
    });

    test('an empty ranking is an empty list, not an error', () async {
      fake.routes['GET /api/v1/catalog/best-sellers'] = (_) => {'productIds': []};
      expect(await HttpCatalogRepository(api).fetchBestSellerIds(), isEmpty);
    });
  });

  group('Deals, launches and offers', () {
    test('a deal carries the product plus what the server recorded', () async {
      fake.routes['GET /api/v1/catalog/deals'] = (_) => [
            {
              'id': 'ck-ss-ball', 'name': 'SS Cricket Ball', 'brand': 'SS',
              'categoryId': 'cricket', 'subcategory': 'Balls', 'unit': 'pc',
              'moq': 24, 'description': '', 'images': [],
              'tiers': [{'minQty': 24, 'unitPrice': 320}],
              'currentPrice': 320, 'previousPrice': 400, 'stockLeft': null,
            }
          ];
      final List<Deal> deals = await HttpCatalogRepository(api).fetchDeals(limit: 5);
      expect(deals.single.product.name, 'SS Cricket Ball');
      expect(deals.single.savingPercent, 20);
      expect(deals.single.isLowStock, isFalse);
      expect(fake.requests.last.url.queryParameters['limit'], '5');
    });

    test('new launches parse as ordinary products', () async {
      fake.routes['GET /api/v1/catalog/new-launches'] = (_) => [
            {
              'id': 'gy-mat', 'name': 'Exercise Mat', 'brand': 'X',
              'categoryId': 'gym', 'subcategory': 'Mats', 'unit': 'pc',
              'moq': 10, 'description': '', 'images': [],
              'tiers': [{'minQty': 10, 'unitPrice': 500}],
              'videoUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
              'videoThumbnailUrl': 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
            }
          ];
      final List<Product> products =
          await HttpCatalogRepository(api).fetchNewLaunches(limit: 3);
      expect(products.single.id, 'gy-mat');
      expect(products.single.hasVideo, isTrue);
    });

    test('no live offer comes back as null, not an error', () async {
      fake.routes['GET /api/v1/promotions/active'] = (_) => {'promotion': null};
      expect(await HttpCatalogRepository(api).fetchActivePromotion(), isNull);
    });

    test('a live offer parses with its link', () async {
      fake.routes['GET /api/v1/promotions/active'] = (_) => {
            'promotion': {
              'id': 'promo-1', 'title': 'Diwali Sale', 'body': '10% off',
              'imageUrl': null, 'linkType': 'category', 'linkTarget': 'cricket',
              'endsAt': '2026-12-31T00:00:00Z',
            }
          };
      final Promotion? p = await HttpCatalogRepository(api).fetchActivePromotion();
      expect(p!.title, 'Diwali Sale');
      expect(p.link, PromotionLink.category);
      expect(p.hasAction, isTrue);
      expect(p.actionLabel, 'Shop Now');
    });
  });

  group('Barcode lookup', () {
    test('a known code resolves to its product', () async {
      fake.routes['GET /api/v1/catalog/barcode/8901234567890'] = (_) => {
            'id': 'ck-kashmir-willow-bat', 'name': 'Kashmir Willow Cricket Bat',
            'brand': 'SPOCART', 'categoryId': 'cricket', 'subcategory': 'Bats',
            'unit': 'pc', 'moq': 10, 'description': '', 'images': [],
            'tiers': [{'minQty': 10, 'unitPrice': 1800}],
          };
      final Product p =
          await HttpCatalogRepository(api).productByBarcode('8901234567890');
      expect(p.id, 'ck-kashmir-willow-bat');
    });

    test('a code no product carries is reported, not guessed at', () async {
      fake.routes['GET /api/v1/catalog/barcode/0000000000000'] = (_) => http.Response(
          jsonEncode({'ok': false, 'message': 'No SPOCART product carries that barcode.'}), 404);
      await expectLater(
        HttpCatalogRepository(api).productByBarcode('0000000000000'),
        throwsA(isA<AppException>().having((AppException e) => e.message, 'message',
            contains('carries that barcode'))),
      );
    });
  });

  group('PIN code lookup', () {
    test('returns the city and state for a PIN', () async {
      fake.routes['GET /api/v1/addresses/pincode/411001'] = (_) => {
            'pincode': '411001',
            'city': 'Pune City',
            'district': 'Pune',
            'state': 'Maharashtra',
          };
      final PincodeLocation place =
          await HttpAddressRepository(api).lookupPincode('411001');
      expect(place.city, 'Pune City');
      expect(place.state, 'Maharashtra');
      expect(place.district, 'Pune');
    });

    test('an unknown PIN surfaces the server message', () async {
      fake.routes['GET /api/v1/addresses/pincode/999999'] = (_) => http.Response(
          jsonEncode({'ok': false, 'message': 'We could not find that PIN code. Please check it.'}), 404);
      await expectLater(
        HttpAddressRepository(api).lookupPincode('999999'),
        throwsA(isA<AppException>().having(
            (AppException e) => e.message, 'message', contains('could not find'))),
      );
    });

    test('an unavailable lookup surfaces the fall-back advice', () async {
      fake.routes['GET /api/v1/addresses/pincode/500001'] = (_) => http.Response(
          jsonEncode({
            'ok': false,
            'message': 'PIN code lookup is unavailable right now. Please type your city and state.',
          }), 503);
      await expectLater(
        HttpAddressRepository(api).lookupPincode('500001'),
        throwsA(isA<AppException>().having((AppException e) => e.message, 'message',
            contains('type your city and state'))),
      );
    });
  });

  test('OTP verify stores the token and sends it on later calls', () async {
    fake.routes['POST /api/v1/auth/otp/send'] = (_) => {'mobile': '9876543210', 'expiresAt': '2026-09-17T10:05:00Z'};
    fake.routes['POST /api/v1/auth/otp/verify'] = (_) => {
          'token': 'jwt-123',
          'user': {'mobile': '9876543210', 'signedInAt': '2026-09-17T10:00:00Z', 'profile': null, 'creditLimit': 100000},
        };
    fake.routes['GET /api/v1/addresses'] = (_) => <dynamic>[];

    final HttpAuthRepository auth = HttpAuthRepository(api, store);
    final OtpChallenge c = await auth.sendOtp('9876543210');
    expect(c.demoCode, isNull);

    final session = await auth.verifyOtp('9876543210', '123456');
    expect(session.mobile, '9876543210');
    expect(session.creditLimit, 100000);

    await HttpAddressRepository(api).fetchAddresses();
    expect(fake.requests.last.headers['authorization'], 'Bearer jwt-123');

    // A new client over the same store restores the token.
    final ApiClient api2 = ApiClient(client: fake.client, baseUrl: 'http://api.test/api/v1');
    final restored = await HttpAuthRepository(api2, store).restoreSession();
    expect(restored?.mobile, '9876543210');
    expect(api2.token, 'jwt-123');
  });

  test('server errors become AppException with the server message', () async {
    fake.routes['POST /api/v1/orders'] = (_) =>
        http.Response(jsonEncode({'ok': false, 'message': 'SS Cricket Ball: minimum order is 24 pc.'}), 400);
    final HttpOrderRepository repo = HttpOrderRepository(api);
    expect(
      () => repo.retryPayment('x'),
      throwsA(isA<AppException>().having((e) => e.message, 'message', 'Route not found.')),
    );
    expect(
      () => repo.placeOrder(OrderRequest(
        snapshot: Order.fromJson(_orderJson()), lines: const [], addressId: 'a1', paymentMethod: PaymentMethod.upi,
      )),
      throwsA(isA<AppException>().having((e) => e.message, 'message', contains('minimum order'))),
    );
  });

  test('401 clears the session through onUnauthorized', () async {
    bool expired = false;
    api.onUnauthorized = () => expired = true;
    fake.routes['GET /api/v1/orders'] = (_) =>
        http.Response(jsonEncode({'ok': false, 'message': 'Your session has expired. Please sign in again.'}), 401);
    await expectLater(HttpOrderRepository(api).fetchOrders(), throwsA(isA<AppException>()));
    expect(expired, isTrue);
  });

  test('placing an order sends lines + method and parses the checkout', () async {
    fake.routes['POST /api/v1/orders'] = (req) {
      final Map<String, dynamic> body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['paymentMethod'], 'razorpay');
      expect(body['addressId'], 'a1');
      expect((body['lines'] as List).single, {'productId': 'fb-match-ball-5', 'quantity': 20, 'size': '5'});
      return {
        'order': _orderJson(),
        'checkout': {
          'keyId': 'rzp_test_x', 'razorpayOrderId': 'order_1', 'amount': 2832000, 'currency': 'INR',
          'description': 'Order SC-2026-0007', 'prefill': {'contact': '+919876543210', 'email': 'r@a.in', 'name': 'Rohit'},
        },
      };
    };
    final PlaceOrderResult r = await HttpOrderRepository(api).placeOrder(OrderRequest(
      snapshot: Order.fromJson(_orderJson()),
      lines: const [CartLine(productId: 'fb-match-ball-5', quantity: 20, size: '5')],
      addressId: 'a1',
      paymentMethod: PaymentMethod.card,
    ));
    expect(r.order.status, OrderStatus.paymentPending);
    expect(r.order.paymentMethod, PaymentMethod.netBanking); // from payment.method
    expect(r.checkout!.amountPaise, 2832000);
    expect(r.checkout!.razorpayOrderId, 'order_1');
  });

  test('payment verification posts the Razorpay ids and returns the paid order', () async {
    fake.routes['POST /api/v1/orders/payments/verify'] = (req) {
      expect(jsonDecode(req.body), {
        'razorpayOrderId': 'order_1', 'razorpayPaymentId': 'pay_1', 'razorpaySignature': 'sig',
      });
      return _orderJson(status: 'placed');
    };
    final Order paid = await HttpOrderRepository(api).verifyPayment(
      const PaymentProof(razorpayOrderId: 'order_1', razorpayPaymentId: 'pay_1', razorpaySignature: 'sig'),
    );
    expect(paid.paid, isTrue);
    expect(paid.status, OrderStatus.placed);
    expect(paid.total, 28320);
  });
}
