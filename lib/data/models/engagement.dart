import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'catalog.dart';

//==============================================================================
// SPOCART — Notifications & quotations
//------------------------------------------------------------------------------
// AppNotification — an inbox entry that deep-links to an order or product.
// QuoteRequest    — a request for quotation (bulk / custom team order).
// Promotion       — an offer the admin panel turned on.
// Deal            — a product with a recorded price drop or low tracked stock.
//==============================================================================

enum NotificationType {
  orderPlaced,
  orderShipped,
  orderDelivered,
  offer,
  newProduct,
  priceDrop,
  quote,
}

extension NotificationTypeMeta on NotificationType {
  IconData get icon => switch (this) {
        NotificationType.orderPlaced => Icons.receipt_long_outlined,
        NotificationType.orderShipped => Icons.local_shipping_outlined,
        NotificationType.orderDelivered => Icons.check_circle_outline_rounded,
        NotificationType.offer => Icons.local_offer_outlined,
        NotificationType.newProduct => Icons.new_releases_outlined,
        NotificationType.priceDrop => Icons.trending_down_rounded,
        NotificationType.quote => Icons.request_quote_outlined,
      };

  Color get color => switch (this) {
        NotificationType.orderPlaced => AppColors.black,
        NotificationType.orderShipped => AppColors.red,
        NotificationType.orderDelivered => AppColors.success,
        NotificationType.offer => AppColors.info,
        NotificationType.newProduct => AppColors.warning,
        NotificationType.priceDrop => AppColors.success,
        NotificationType.quote => AppColors.black,
      };

  static NotificationType fromName(String? name) =>
      NotificationType.values.firstWhere(
        (t) => t.name == name,
        orElse: () => NotificationType.offer,
      );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    this.read = false,
    this.orderId,
    this.productId,
    this.quoteId,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime time;
  final bool read;
  final String? orderId;
  final String? productId;
  final String? quoteId;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        time: time,
        read: read ?? this.read,
        orderId: orderId,
        productId: productId,
        quoteId: quoteId,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type.name,
        'title': title,
        'body': body,
        'time': time.toIso8601String(),
        'read': read,
        'orderId': orderId,
        'productId': productId,
        'quoteId': quoteId,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        type: NotificationTypeMeta.fromName(json['type'] as String?),
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        time: DateTime.parse((json['time'] ?? json['createdAt']) as String),
        read: json['read'] as bool? ?? false,
        orderId: json['orderId'] as String?,
        productId: json['productId'] as String?,
        quoteId: json['quoteId'] as String?,
      );
}

enum QuoteKind { bulk, custom, csv }

extension QuoteKindLabel on QuoteKind {
  String get label => switch (this) {
        QuoteKind.bulk => 'Bulk Quote',
        QuoteKind.custom => 'Custom / Team Order',
        QuoteKind.csv => 'Bulk Order Upload',
      };

  static QuoteKind fromName(String? name) => QuoteKind.values.firstWhere(
        (k) => k.name == name,
        orElse: () => QuoteKind.bulk,
      );
}

enum QuoteStatus { submitted, underReview, quoted, accepted, declined }

extension QuoteStatusMeta on QuoteStatus {
  String get label => switch (this) {
        QuoteStatus.submitted => 'Submitted',
        QuoteStatus.underReview => 'Under Review',
        QuoteStatus.quoted => 'Quote Ready',
        QuoteStatus.accepted => 'Accepted',
        QuoteStatus.declined => 'Declined',
      };

  Color get color => switch (this) {
        QuoteStatus.submitted => AppColors.textSoft,
        QuoteStatus.underReview => AppColors.warning,
        QuoteStatus.quoted => AppColors.info,
        QuoteStatus.accepted => AppColors.success,
        QuoteStatus.declined => AppColors.red,
      };

  static QuoteStatus fromName(String? name) => QuoteStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => QuoteStatus.submitted,
      );
}

class QuoteItem {
  const QuoteItem({
    required this.description,
    required this.quantity,
    this.productId,
    this.size,
  });

  final String description;
  final int quantity;
  final String? productId;
  final String? size;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'description': description,
        'quantity': quantity,
        'productId': productId,
        'size': size,
      };

  factory QuoteItem.fromJson(Map<String, dynamic> json) => QuoteItem(
        description: json['description'] as String? ?? '',
        quantity: json['quantity'] as int? ?? 1,
        productId: json['productId'] as String?,
        size: json['size'] as String?,
      );
}

class QuoteRequest {
  const QuoteRequest({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.items,
    required this.notes,
    this.status = QuoteStatus.submitted,
    this.quotedTotal,
    this.designFileName,
  });

  final String id;
  final QuoteKind kind;
  final DateTime createdAt;
  final List<QuoteItem> items;
  final String notes;
  final QuoteStatus status;
  final double? quotedTotal;

  /// For custom team orders: the artwork file the buyer attached, if any.
  final String? designFileName;

  int get totalUnits => items.fold(0, (sum, i) => sum + i.quantity);

  QuoteRequest copyWith({QuoteStatus? status, double? quotedTotal}) =>
      QuoteRequest(
        id: id,
        kind: kind,
        createdAt: createdAt,
        items: items,
        notes: notes,
        status: status ?? this.status,
        quotedTotal: quotedTotal ?? this.quotedTotal,
        designFileName: designFileName,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind.name,
        'createdAt': createdAt.toIso8601String(),
        'items': items.map((i) => i.toJson()).toList(),
        'notes': notes,
        'status': status.name,
        'quotedTotal': quotedTotal,
        'designFileName': designFileName,
      };

  factory QuoteRequest.fromJson(Map<String, dynamic> json) => QuoteRequest(
        id: json['id'] as String,
        kind: QuoteKindLabel.fromName(json['kind'] as String?),
        createdAt: DateTime.parse(json['createdAt'] as String),
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((i) => QuoteItem.fromJson(Map<String, dynamic>.from(i as Map)))
            .toList(),
        notes: json['notes'] as String? ?? '',
        status: QuoteStatusMeta.fromName(json['status'] as String?),
        quotedTotal: (json['quotedTotal'] as num?)?.toDouble(),
        designFileName: json['designFileName'] as String?,
      );
}

//------------------------------------------------------------------------------
// Promotions
//------------------------------------------------------------------------------

/// Where tapping a promotion takes the buyer. The server validated the target
/// when it was saved, so the app only has to route — never judge safety.
enum PromotionLink { none, product, category, url }

PromotionLink _promotionLinkFrom(String? raw) => switch (raw) {
      'product' => PromotionLink.product,
      'category' => PromotionLink.category,
      'url' => PromotionLink.url,
      _ => PromotionLink.none,
    };

/// An offer or announcement the admin panel turned on. Everything about it —
/// text, image, timing, who sees it — comes from the server.
class Promotion {
  const Promotion({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    this.link = PromotionLink.none,
    this.linkTarget,
    required this.endsAt,
  });

  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final PromotionLink link;
  final String? linkTarget;
  final DateTime endsAt;

  bool get hasAction => link != PromotionLink.none && (linkTarget ?? '').isNotEmpty;

  /// Label for the action button, chosen from where the promotion leads.
  String get actionLabel => switch (link) {
        PromotionLink.product => 'View Product',
        PromotionLink.category => 'Shop Now',
        PromotionLink.url => 'Know More',
        PromotionLink.none => 'OK',
      };

  factory Promotion.fromJson(Map<String, dynamic> json) => Promotion(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        imageUrl: json['imageUrl'] as String?,
        link: _promotionLinkFrom(json['linkType'] as String?),
        linkTarget: json['linkTarget'] as String?,
        endsAt: DateTime.tryParse(json['endsAt'] as String? ?? '') ??
            DateTime.now().add(const Duration(days: 1)),
      );
}

//------------------------------------------------------------------------------
// Deals
//------------------------------------------------------------------------------

/// A product on the Deals shelf. [previousPrice] exists only because the server
/// recorded that price change, and [stockLeft] only because the seller tracks
/// that product's stock — so neither is ever a made-up number.
class Deal {
  const Deal({
    required this.product,
    required this.currentPrice,
    this.previousPrice,
    this.stockLeft,
  });

  final Product product;
  final double currentPrice;
  final double? previousPrice;
  final int? stockLeft;

  bool get hasDrop => previousPrice != null && previousPrice! > currentPrice;
  bool get isLowStock => stockLeft != null && stockLeft! > 0;

  double get saving => hasDrop ? previousPrice! - currentPrice : 0;

  /// Whole-percent saving, for the badge. 0 when there is no recorded drop.
  int get savingPercent =>
      hasDrop && previousPrice! > 0 ? ((saving / previousPrice!) * 100).round() : 0;

  factory Deal.fromJson(Map<String, dynamic> json) => Deal(
        product: Product.fromJson(json),
        currentPrice: (json['currentPrice'] as num?)?.toDouble() ?? 0,
        previousPrice: (json['previousPrice'] as num?)?.toDouble(),
        stockLeft: (json['stockLeft'] as num?)?.toInt(),
      );
}

//------------------------------------------------------------------------------
// Reviews
//------------------------------------------------------------------------------

/// One buyer's review. The server only ever returns reviews it has proved were
/// written by someone whose order for that product was delivered, so
/// [verifiedBuyer] is a fact rather than something the client decided.
class ProductReview {
  const ProductReview({
    required this.id,
    required this.productId,
    required this.rating,
    required this.title,
    required this.body,
    required this.photos,
    required this.createdAt,
    required this.author,
    this.verifiedBuyer = true,
    this.mine = false,
  });

  final String id;
  final String productId;
  final int rating;
  final String title;
  final String body;
  final List<String> photos;
  final DateTime createdAt;

  /// Business name, or a masked mobile. Never the full number.
  final String author;
  final bool verifiedBuyer;

  /// True for the signed-in buyer's own review, so it can be edited.
  final bool mine;

  factory ProductReview.fromJson(Map<String, dynamic> json) => ProductReview(
        id: json['id'] as String,
        productId: json['productId'] as String? ?? '',
        rating: (json['rating'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        photos: (json['photos'] as List<dynamic>? ?? const <dynamic>[])
            .map((dynamic e) => e.toString())
            .toList(growable: false),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        author: json['author'] as String? ?? 'SPOCART buyer',
        verifiedBuyer: json['verifiedBuyer'] as bool? ?? true,
        mine: json['mine'] as bool? ?? false,
      );
}

/// A page of reviews with the summary the product page shows above them.
class ReviewPage {
  const ReviewPage({
    required this.reviews,
    required this.total,
    required this.average,
    required this.breakdown,
  });

  final List<ProductReview> reviews;
  final int total;
  final double average;

  /// Star → how many reviews gave it, for the distribution bars.
  final Map<int, int> breakdown;

  bool get isEmpty => total == 0;

  static const ReviewPage empty = ReviewPage(
    reviews: <ProductReview>[],
    total: 0,
    average: 0,
    breakdown: <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
  );

  factory ReviewPage.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> raw =
        Map<String, dynamic>.from(json['breakdown'] as Map? ?? const <String, dynamic>{});
    return ReviewPage(
      reviews: (json['reviews'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => ProductReview.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      average: (json['average'] as num?)?.toDouble() ?? 0,
      breakdown: <int, int>{
        for (int star = 1; star <= 5; star++)
          star: (raw['$star'] as num?)?.toInt() ?? 0,
      },
    );
  }
}

/// A product the buyer has received and can still review.
class ReviewableProduct {
  const ReviewableProduct({
    required this.productId,
    required this.name,
    required this.image,
  });

  final String productId;
  final String name;
  final String image;

  factory ReviewableProduct.fromJson(Map<String, dynamic> json) => ReviewableProduct(
        productId: json['productId'] as String,
        name: json['name'] as String? ?? '',
        image: json['image'] as String? ?? '',
      );
}
