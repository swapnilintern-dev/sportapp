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
// Order history, placement and invoices. Also raises inbox notifications when
// an order is placed or its status advances.
//==============================================================================

class OrdersController extends ChangeNotifier {
  OrdersController(this._repository, this._notifications);

  final OrderRepository _repository;
  final NotificationsController _notifications;

  List<Order> _orders = <Order>[];
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  List<Order> get orders => List<Order>.unmodifiable(_orders);
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
      await _raiseStatusNotifications(fresh);
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

  Order? byId(String id) {
    for (final Order o in _orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// Snapshots the cart into an order and submits it. Throws [AppException].
  Future<Order> placeOrder({
    required CartController cart,
    required Address address,
    required PaymentMethod paymentMethod,
    required bool paid,
  }) async {
    final List<OrderLine> lines = cart.toOrderLines();
    if (lines.isEmpty) throw const AppException('Your cart is empty.');

    final DateTime now = DateTime.now();
    final Order draft = Order(
      id: Ids.order(now),
      placedAt: now,
      status: OrderStatus.placed,
      lines: lines,
      subtotal: cart.subtotal,
      gst: cart.gst,
      total: cart.total,
      address: address,
      paymentMethod: paymentMethod,
      paid: paid,
      etaStart: now.add(const Duration(days: 3)),
      etaEnd: now.add(const Duration(days: 7)),
      invoiceId: Ids.invoice(now),
      statusUpdatedAt: now,
      trackingId: 'SPK${now.millisecondsSinceEpoch.toString().substring(5)}',
    );

    final Order placed = await _repository.placeOrder(draft);
    _orders.insert(0, placed);
    _loaded = true;
    notifyListeners();

    await _notifications.push(
      type: NotificationType.orderPlaced,
      title: 'Order Placed',
      body: 'Your order #${placed.id} has been placed and is being processed.',
      orderId: placed.id,
    );
    return placed;
  }

  /// Marks a Pay-Later order as settled.
  Future<void> markPaid(String orderId) async {
    final int i = _orders.indexWhere((o) => o.id == orderId);
    if (i < 0) return;
    _orders[i] = _orders[i].copyWith(paid: true);
    notifyListeners();
    await _repository.saveAll(_orders);
  }

  Future<void> _raiseStatusNotifications(List<Order> fresh) async {
    for (final Order order in fresh) {
      if (order.status.isShipped) {
        if (!_notifications.hasOrderEvent(
            order.id, NotificationType.orderShipped)) {
          await _notifications.push(
            type: NotificationType.orderShipped,
            title: 'Order Shipped',
            body: 'Your order #${order.id} has been dispatched.',
            orderId: order.id,
          );
        }
      } else if (order.status == OrderStatus.delivered) {
        if (!_notifications.hasOrderEvent(
            order.id, NotificationType.orderDelivered)) {
          await _notifications.push(
            type: NotificationType.orderDelivered,
            title: 'Order Delivered',
            body: 'Order #${order.id} was delivered successfully.',
            orderId: order.id,
          );
        }
      }
    }
  }

  //----------------------------------------------------------------------------
  // Derived views
  //----------------------------------------------------------------------------
  List<Invoice> get invoices => _orders
      .map((o) => Invoice(
            id: o.invoiceId,
            orderId: o.id,
            date: o.placedAt,
            amount: o.total,
            paid: o.paid,
          ))
      .toList(growable: false);

  double get totalPurchases => _orders
      .where((o) => o.status != OrderStatus.cancelled)
      .fold(0, (sum, o) => sum + o.total);

  int get pendingCount => _orders.where((o) => o.status.isOpen).length;

  double get outstandingPayment => _orders
      .where((o) => !o.paid && o.status != OrderStatus.cancelled)
      .fold(0, (sum, o) => sum + o.total);

  /// Orders that contain a product bought in an earlier order.
  int get repeatOrderCount {
    final Set<String> seen = <String>{};
    int repeats = 0;
    for (final Order o in _orders.reversed) {
      final bool repeat = o.lines.any((l) => seen.contains(l.productId));
      if (repeat) repeats++;
      seen.addAll(o.lines.map((l) => l.productId));
    }
    return repeats;
  }

  void reset() {
    _orders = <Order>[];
    _loaded = false;
    _error = null;
    notifyListeners();
  }
}
