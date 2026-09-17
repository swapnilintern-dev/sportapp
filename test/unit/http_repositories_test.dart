import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport/core/network/api_client.dart';
import 'package:sport/data/local/local_store.dart';
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
