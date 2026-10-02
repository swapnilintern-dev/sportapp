import 'package:flutter/material.dart';

import '../../core/utils/icon_names.dart';

//==============================================================================
// SPOCART — Catalogue models
//------------------------------------------------------------------------------
// ProductCategory / Product / PriceTier. Products carry tiered (slab) B2B pricing:
// the price per unit drops as the ordered quantity climbs. The display "price
// range" on cards is derived from the cheapest and dearest slabs.
//==============================================================================

class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.imageAsset,
    this.subcategories = const <String>[],
  });

  final String id;
  final String name;
  final IconData icon;
  final String imageAsset;

  /// Filter chips shown on the category listing (e.g. Bats, Balls, Gear).
  final List<String> subcategories;

  factory ProductCategory.fromJson(Map<String, dynamic> json) => ProductCategory(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        icon: iconFromName(json['icon'] as String?),
        imageAsset: json['imageUrl'] as String? ?? '',
        subcategories: (json['subcategories'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

class PriceTier {
  const PriceTier({required this.minQty, required this.unitPrice});

  /// Applies once the ordered quantity reaches [minQty] units.
  final int minQty;
  final double unitPrice;

  factory PriceTier.fromJson(Map<String, dynamic> json) => PriceTier(
        minQty: (json['minQty'] as num).toInt(),
        unitPrice: (json['unitPrice'] as num).toDouble(),
      );
}

class ProductFeature {
  const ProductFeature({required this.label, required this.icon});

  final String label;
  final IconData icon;

  factory ProductFeature.fromJson(Map<String, dynamic> json) => ProductFeature(
        label: json['label'] as String? ?? '',
        icon: iconFromName(json['icon'] as String?, fallback: Icons.check_circle_outline),
      );
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.categoryId,
    required this.subcategory,
    required this.unit,
    required this.moq,
    required this.tiers,
    required this.description,
    required this.images,
    this.features = const <ProductFeature>[],
    this.sizes = const <String>[],
    this.rating = 4.5,
    this.reviewCount = 0,
    this.inStock = true,
    this.popular = false,
    this.customisable = false,
    this.videoUrl,
    this.videoThumbnailUrl,
    this.stockLeft,
  });

  final String id;
  final String name;
  final String brand;
  final String categoryId;
  final String subcategory;

  /// Short selling unit: "pc", "pair", "set", "box".
  final String unit;

  /// Minimum order quantity.
  final int moq;

  /// Ascending by [PriceTier.minQty]; the first entry is the base price.
  final List<PriceTier> tiers;

  final String description;

  /// Asset paths or URLs; the first is the primary image.
  final List<String> images;
  final List<ProductFeature> features;
  final List<String> sizes;
  final double rating;
  final int reviewCount;
  final bool inStock;
  final bool popular;
  final bool customisable;

  /// Official product video (YouTube), validated by the server. Null when the
  /// product has none; [videoThumbnailUrl] is set exactly when this is.
  final String? videoUrl;
  final String? videoThumbnailUrl;

  /// Units left, and only when the seller actually tracks this product's stock
  /// and it is running low. Null means we say nothing about quantity rather
  /// than inventing scarcity.
  final int? stockLeft;

  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;

  String get primaryImage => images.isEmpty ? '' : images.first;

  factory Product.fromJson(Map<String, dynamic> json) {
    final List<PriceTier> tiers = (json['tiers'] as List<dynamic>? ?? const [])
        .map((t) => PriceTier.fromJson(Map<String, dynamic>.from(t as Map)))
        .toList();
    return Product(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? '',
      subcategory: json['subcategory'] as String? ?? '',
      unit: json['unit'] as String? ?? 'pc',
      moq: (json['moq'] as num?)?.toInt() ?? 1,
      tiers: tiers.isEmpty ? const [PriceTier(minQty: 1, unitPrice: 0)] : tiers,
      description: json['description'] as String? ?? '',
      images: (json['images'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
      features: (json['features'] as List<dynamic>? ?? const [])
          .map((f) => ProductFeature.fromJson(Map<String, dynamic>.from(f as Map)))
          .toList(),
      sizes: (json['sizes'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      inStock: json['inStock'] as bool? ?? true,
      popular: json['popular'] as bool? ?? false,
      customisable: json['customisable'] as bool? ?? false,
      videoUrl: json['videoUrl'] as String?,
      videoThumbnailUrl: json['videoThumbnailUrl'] as String?,
      stockLeft: (json['stockLeft'] as num?)?.toInt(),
    );
  }

  /// Highest per-unit price (smallest slab).
  double get basePrice => tiers.first.unitPrice;

  /// Lowest per-unit price (largest slab).
  double get bestPrice => tiers.last.unitPrice;

  bool get hasPriceRange => basePrice != bestPrice;

  /// The per-unit price that applies for [qty] units.
  double priceForQuantity(int qty) {
    double price = tiers.first.unitPrice;
    for (final PriceTier tier in tiers) {
      if (qty >= tier.minQty) price = tier.unitPrice;
    }
    return price;
  }

  /// "10 - 49", "50 - 99", "500+" labels for the bulk-pricing table.
  String tierRangeLabel(int index) {
    final PriceTier tier = tiers[index];
    if (index == tiers.length - 1) return '${tier.minQty}+';
    return '${tier.minQty} - ${tiers[index + 1].minQty - 1}';
  }

  bool matchesQuery(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        brand.toLowerCase().contains(q) ||
        subcategory.toLowerCase().contains(q) ||
        categoryId.toLowerCase().contains(q);
  }
}

enum ProductSort { relevance, priceLowHigh, priceHighLow, rating, nameAz }

extension ProductSortLabel on ProductSort {
  String get label => switch (this) {
        ProductSort.relevance => 'Relevance',
        ProductSort.priceLowHigh => 'Price: Low to High',
        ProductSort.priceHighLow => 'Price: High to Low',
        ProductSort.rating => 'Top Rated',
        ProductSort.nameAz => 'Name: A to Z',
      };
}

List<Product> sortProducts(List<Product> products, ProductSort sort) {
  final List<Product> copy = List<Product>.of(products);
  switch (sort) {
    case ProductSort.relevance:
      break;
    case ProductSort.priceLowHigh:
      copy.sort((a, b) => a.bestPrice.compareTo(b.bestPrice));
    case ProductSort.priceHighLow:
      copy.sort((a, b) => b.bestPrice.compareTo(a.bestPrice));
    case ProductSort.rating:
      copy.sort((a, b) => b.rating.compareTo(a.rating));
    case ProductSort.nameAz:
      copy.sort((a, b) => a.name.compareTo(b.name));
  }
  return copy;
}
