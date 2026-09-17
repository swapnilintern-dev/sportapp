import 'package:flutter/foundation.dart';

import '../data/models/account.dart';
import '../data/models/engagement.dart';
import '../data/models/order.dart';
import '../data/repositories/repositories.dart';
import 'cart_controller.dart';
import 'notifications_controller.dart';

//==============================================================================
// SPOCART — Orders controller
//------------------------------------------------------------------------------
// Order history, placement, payment confirmation, invoices and dashboard.
//==============================================================================

class OrdersController extends ChangeNotifier {
  OrdersController(this._repository, this._notifications);

  final OrderRepository _repository;
  final NotificationsController _notifications;

  List<Order> _orders = <Order>[];
  List<Invoice> _invoices = <Invoice>[];
  DashboardStats? _dashboard;
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  List<Order> get orders => List<Order>.unmodifiable(_orders);
  List<Invoice> get invoices => List<Invoice>.unmodifiable(_invoices);
  DashboardStats? get dashboard => _dashboard;
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  Future<void> load({bool force = false}) async {
    if (_loading || (_loaded && !force)) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final List<Order> fresh = await _repository.fetchOrders();
      await _raiseLocalStatusNotifications(fresh);
      _orders = fresh;
      _loaded = true;
    } on AppException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load your orders. Please try again.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadInvoices() async {
    try {
      _invoices = await _repository.fetchInvoices();
      notifyListeners();
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadDashboard({required double creditLimit}) async {
    try {
      _dashboard = await _repository.fetchDashboard(creditLimit: creditLimit);
      notifyListeners();
    } on AppException catch (e) {
      _error = e.message;
      notifyListeners();
      rethrow;
    }
  }

  Order? byId(String id) {
    for (final Order o in _orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// Snapshots the cart into an order and submits it. When the result carries
  /// a [CheckoutSession] the caller must run the Razorpay checkout and then
  /// call [confirmPayment]. Throws [AppException].
  Future<PlaceOrderResult> placeOrder({
    required CartController cart,
    required Address address,
    required PaymentMethod paymentMethod,
  }) async {
    final List<OrderLine> lines = cart.toOrderLines();
    if (lines.isEmpty) throw const AppException('Your cart is empty.');

    final DateTime now = DateTime.now();
    final bool credit = paymentMethod == PaymentMethod.payLater;
    final Order snapshot = Order(
      id: Ids.order(now),
      placedAt: now,
      status: credit ? OrderStatus.placed : OrderStatus.paymentPending,
      lines: lines,
      subtotal: cart.subtotal,
      gst: cart.gst,
      total: cart.total,
      address: address,
      paymentMethod: paymentMethod,
      paid: false,
      etaStart: now.add(const Duration(days: 3)),
      etaEnd: now.add(const Duration(days: 7)),
      invoiceId: Ids.invoice(now),
      statusUpdatedAt: now,
      trackingId: 'SPK${now.millisecondsSinceEpoch.toString().substring(5)}',
    );

    final PlaceOrderResult result = await _repository.placeOrder(OrderRequest(
      snapshot: snapshot,
      lines: cart.lines,
      addressId: address.id,
      paymentMethod: paymentMethod,
    ));
    _upsert(result.order);

    if (result.checkout == null) {
      await _notifications.pushLocal(
        type: NotificationType.orderPlaced,
        title: 'Order Placed',
        body: 'Your order #${result.order.id} has been placed and is being processed.',
        orderId: result.order.id,
      );
    }
    return result;
  }

  /// Confirms a completed Razorpay checkout with the server.
  Future<Order> confirmPayment(PaymentProof proof) async {
    final Order paid = await _repository.verifyPayment(proof);
    _upsert(paid);
    _notifications.load(force: true);
    return paid;
  }

  Future<PlaceOrderResult> retryPayment(String orderId) async {
    final PlaceOrderResult result = await _repository.retryPayment(orderId);
    _upsert(result.order);
    return result;
  }

  void _upsert(Order order) {
    final int i = _orders.indexWhere((o) => o.id == order.id);
    if (i >= 0) {
      _orders[i] = order;
    } else {
      _orders.insert(0, order);
    }
    _loaded = true;
    notifyListeners();
  }

  /// Demo mode only: the server raises these itself.
  Future<void> _raiseLocalStatusNotifications(List<Order> fresh) async {
    if (!_notifications.localEvents) return;
    for (final Order order in fresh) {
      if (order.status.isShipped &&
          !_notifications.hasOrderEvent(order.id, NotificationType.orderShipped)) {
        await _notifications.pushLocal(
          type: NotificationType.orderShipped,
          title: 'Order Shipped',
          body: 'Your order #${order.id} has been dispatched.',
          orderId: order.id,
        );
      } else if (order.status == OrderStatus.delivered &&
          !_notifications.hasOrderEvent(order.id, NotificationType.orderDelivered)) {
        await _notifications.pushLocal(
          type: NotificationType.orderDelivered,
          title: 'Order Delivered',
          body: 'Order #${order.id} was delivered successfully.',
          orderId: order.id,
        );
      }
    }
  }

  void reset() {
    _orders = <Order>[];
    _invoices = <Invoice>[];
    _dashboard = null;
    _loaded = false;
    _error = null;
    notifyListeners();
  }
}
