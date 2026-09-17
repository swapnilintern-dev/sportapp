import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'account.dart';

//==============================================================================
// SPOCART — Cart & order models
//------------------------------------------------------------------------------
// CartLine       — a product id + quantity (+ optional size) in the cart.
// PaymentMethod  — what the buyer chose at checkout.
// OrderStatus    — the tracking pipeline, in order.
// Order          — a frozen snapshot of the cart at purchase time.
// Invoice        — one per placed order.
//==============================================================================

class CartLine {
  const CartLine({
    required this.productId,
    required this.quantity,
    this.size,
  });

  final String productId;
  final int quantity;
  final String? size;

  /// Cart lines are keyed by product + size so two sizes stay separate.
  String get key => size == null ? productId : '$productId#$size';

  CartLine copyWith({int? quantity}) => CartLine(
        productId: productId,
        quantity: quantity ?? this.quantity,
        size: size,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'productId': productId,
        'quantity': quantity,
        'size': size,
      };

  factory CartLine.fromJson(Map<String, dynamic> json) => CartLine(
        productId: json['productId'] as String,
        quantity: json['quantity'] as int? ?? 1,
        size: json['size'] as String?,
      );
}

enum PaymentMethod { upi, netBanking, card, wallet, payLater }

extension PaymentMethodMeta on PaymentMethod {
  String get title => switch (this) {
        PaymentMethod.upi => 'UPI',
        PaymentMethod.netBanking => 'Net Banking',
        PaymentMethod.card => 'Card / Debit Card',
        PaymentMethod.wallet => 'Wallets',
        PaymentMethod.payLater => 'Pay Later (Business Credit)',
      };

  String get subtitle => switch (this) {
        PaymentMethod.upi => 'Fast & Secure',
        PaymentMethod.netBanking => 'All major banks',
        PaymentMethod.card => 'Visa, Mastercard, RuPay',
        PaymentMethod.wallet => 'Paytm, PhonePe, Amazon Pay',
        PaymentMethod.payLater => 'Invoice now, pay within 30 days',
      };

  IconData get icon => switch (this) {
        PaymentMethod.upi => Icons.qr_code_2_rounded,
        PaymentMethod.netBanking => Icons.account_balance_outlined,
        PaymentMethod.card => Icons.credit_card_rounded,
        PaymentMethod.wallet => Icons.account_balance_wallet_outlined,
        PaymentMethod.payLater => Icons.schedule_rounded,
      };

  static PaymentMethod fromName(String? name) => PaymentMethod.values.firstWhere(
        (m) => m.name == name,
        orElse: () => PaymentMethod.upi,
      );
}

/// Order pipeline. The index doubles as the tracking-timeline position.
enum OrderStatus {
  placed,
  packed,
  dispatched,
  outForDelivery,
  delivered,
  cancelled,
}

extension OrderStatusMeta on OrderStatus {
  String get label => switch (this) {
        OrderStatus.placed => 'Processing',
        OrderStatus.packed => 'Packed',
        OrderStatus.dispatched => 'Shipped',
        OrderStatus.outForDelivery => 'Out for Delivery',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
      };

  /// Title used on the tracking timeline.
  String get stepTitle => switch (this) {
        OrderStatus.placed => 'Order Placed',
        OrderStatus.packed => 'Packed',
        OrderStatus.dispatched => 'Dispatched',
        OrderStatus.outForDelivery => 'Out for Delivery',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
      };

  Color get color => switch (this) {
        OrderStatus.placed => AppColors.warning,
        OrderStatus.packed => AppColors.info,
        OrderStatus.dispatched => AppColors.info,
        OrderStatus.outForDelivery => AppColors.info,
        OrderStatus.delivered => AppColors.success,
        OrderStatus.cancelled => AppColors.red,
      };

  IconData get icon => switch (this) {
        OrderStatus.placed => Icons.receipt_long_outlined,
        OrderStatus.packed => Icons.inventory_2_outlined,
        OrderStatus.dispatched => Icons.local_shipping_outlined,
        OrderStatus.outForDelivery => Icons.delivery_dining_outlined,
        OrderStatus.delivered => Icons.check_circle_outline_rounded,
        OrderStatus.cancelled => Icons.cancel_outlined,
      };

  bool get isPending =>
      this == OrderStatus.placed || this == OrderStatus.packed;
  bool get isShipped =>
      this == OrderStatus.dispatched || this == OrderStatus.outForDelivery;
  bool get isOpen => this != OrderStatus.delivered && this != OrderStatus.cancelled;

  static OrderStatus fromName(String? name) => OrderStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => OrderStatus.placed,
      );
}

/// The five tracking steps shown on Order Details.
const List<OrderStatus> kTrackingSteps = <OrderStatus>[
  OrderStatus.placed,
  OrderStatus.packed,
  OrderStatus.dispatched,
  OrderStatus.outForDelivery,
  OrderStatus.delivered,
];

class OrderLine {
  const OrderLine({
    required this.productId,
    required this.name,
    required this.image,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    this.size,
  });

  final String productId;
  final String name;
  final String image;
  final String unit;
  final int quantity;
  final double unitPrice;
  final String? size;

  double get lineTotal => unitPrice * quantity;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'productId': productId,
        'name': name,
        'image': image,
        'unit': unit,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'size': size,
      };

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
        productId: json['productId'] as String,
        name: json['name'] as String? ?? '',
        image: json['image'] as String? ?? '',
        unit: json['unit'] as String? ?? 'pc',
        quantity: json['quantity'] as int? ?? 1,
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
        size: json['size'] as String?,
      );
}

class Order {
  const Order({
    required this.id,
    required this.placedAt,
    required this.status,
    required this.lines,
    required this.subtotal,
    required this.gst,
    required this.total,
    required this.address,
    required this.paymentMethod,
    required this.paid,
    required this.etaStart,
    required this.etaEnd,
    required this.invoiceId,
    this.statusUpdatedAt,
    this.trackingId,
  });

  final String id;
  final DateTime placedAt;
  final OrderStatus status;
  final List<OrderLine> lines;
  final double subtotal;
  final double gst;
  final double total;
  final Address address;
  final PaymentMethod paymentMethod;

  /// False for Pay Later orders until the invoice is settled.
  final bool paid;
  final DateTime etaStart;
  final DateTime etaEnd;
  final String invoiceId;
  final DateTime? statusUpdatedAt;
  final String? trackingId;

  int get totalUnits => lines.fold(0, (sum, l) => sum + l.quantity);
  int get itemCount => lines.length;
  String get primaryImage => lines.isEmpty ? '' : lines.first.image;

  /// Index of [status] within [kTrackingSteps]; -1 when cancelled.
  int get trackingIndex => kTrackingSteps.indexOf(status);

  Order copyWith({OrderStatus? status, bool? paid, DateTime? statusUpdatedAt}) =>
      Order(
        id: id,
        placedAt: placedAt,
        status: status ?? this.status,
        lines: lines,
        subtotal: subtotal,
        gst: gst,
        total: total,
        address: address,
        paymentMethod: paymentMethod,
        paid: paid ?? this.paid,
        etaStart: etaStart,
        etaEnd: etaEnd,
        invoiceId: invoiceId,
        statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
        trackingId: trackingId,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'placedAt': placedAt.toIso8601String(),
        'status': status.name,
        'lines': lines.map((l) => l.toJson()).toList(),
        'subtotal': subtotal,
        'gst': gst,
        'total': total,
        'address': address.toJson(),
        'paymentMethod': paymentMethod.name,
        'paid': paid,
        'etaStart': etaStart.toIso8601String(),
        'etaEnd': etaEnd.toIso8601String(),
        'invoiceId': invoiceId,
        'statusUpdatedAt': statusUpdatedAt?.toIso8601String(),
        'trackingId': trackingId,
      };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        placedAt: DateTime.parse(json['placedAt'] as String),
        status: OrderStatusMeta.fromName(json['status'] as String?),
        lines: (json['lines'] as List<dynamic>? ?? const [])
            .map((l) => OrderLine.fromJson(Map<String, dynamic>.from(l as Map)))
            .toList(),
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
        gst: (json['gst'] as num?)?.toDouble() ?? 0,
        total: (json['total'] as num?)?.toDouble() ?? 0,
        address:
            Address.fromJson(Map<String, dynamic>.from(json['address'] as Map)),
        paymentMethod:
            PaymentMethodMeta.fromName(json['paymentMethod'] as String?),
        paid: json['paid'] as bool? ?? true,
        etaStart: DateTime.parse(json['etaStart'] as String),
        etaEnd: DateTime.parse(json['etaEnd'] as String),
        invoiceId: json['invoiceId'] as String? ?? '',
        statusUpdatedAt: json['statusUpdatedAt'] == null
            ? null
            : DateTime.tryParse(json['statusUpdatedAt'] as String),
        trackingId: json['trackingId'] as String?,
      );
}

class Invoice {
  const Invoice({
    required this.id,
    required this.orderId,
    required this.date,
    required this.amount,
    required this.paid,
  });

  final String id;
  final String orderId;
  final DateTime date;
  final double amount;
  final bool paid;
}
