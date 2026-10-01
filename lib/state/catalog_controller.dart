import 'package:flutter/foundation.dart';

import '../data/models/catalog.dart';
import '../data/repositories/repositories.dart';

//==============================================================================
// SPOCART — Catalogue controller
//------------------------------------------------------------------------------
// Loads categories + products once and serves lookups to every screen. Holds
// loading / error state so Home, Categories and Listing can render skeletons
// and retry without duplicating fetch logic.
//==============================================================================

class CatalogController extends ChangeNotifier {
  CatalogController(this._repository);

  final CatalogRepository _repository;

  List<ProductCategory> _categories = const <ProductCategory>[];
  List<Product> _products = const <Product>[];
  Map<String, Product> _byId = const <String, Product>{};
  List<String> _bestSellerIds = const <String>[];
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  List<ProductCategory> get categories => _categories;
  List<Product> get products => _products;
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (_loaded && !force) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final List<ProductCategory> categories = await _repository.fetchCategories();
      final List<Product> products = await _repository.fetchProducts();
      _categories = categories;
      _products = products;
      _byId = <String, Product>{for (final Product p in products) p.id: p};
      _loaded = true;
      // Ranking is a nice-to-have on top of the catalogue: if it fails the
      // catalogue still loads and Home falls back to the popular flag.
      try {
        _bestSellerIds = await _repository.fetchBestSellerIds(limit: 10);
      } catch (_) {
        _bestSellerIds = const <String>[];
      }
    } on AppException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load the catalogue. Please try again.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Product? productById(String id) => _byId[id];

  ProductCategory? categoryById(String id) {
    for (final ProductCategory c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<Product> get popular =>
      _products.where((p) => p.popular).toList(growable: false);

  /// Products in best-seller order. Falls back to the catalogue's own popular
  /// flag while nothing has sold yet, so Home is never empty on a new store.
  List<Product> get bestSellers {
    final List<Product> ranked = <Product>[];
    for (final String id in _bestSellerIds) {
      final Product? p = _byId[id];
      if (p != null) ranked.add(p);
    }
    return ranked.isEmpty ? popular : ranked;
  }

  /// How many of the top sellers carry the Trending badge in listings.
  static const int trendingCount = 5;

  Set<String> get _trendingIds =>
      _bestSellerIds.take(trendingCount).toSet();

  /// True for the handful of genuine top sellers, so the badge stays a signal.
  /// Never true while the ranking is empty — a badge on everything says nothing.
  bool isTrending(String productId) => _trendingIds.contains(productId);

  List<Product> inCategory(String categoryId, {String? subcategory}) =>
      _products
          .where((p) =>
              p.categoryId == categoryId &&
              (subcategory == null || p.subcategory == subcategory))
          .toList(growable: false);

  List<Product> search(String query) {
    final String q = query.trim();
    if (q.isEmpty) return const <Product>[];
    return _products.where((p) => p.matchesQuery(q)).toList(growable: false);
  }

  /// Products a buyer might also want, excluding [product] itself.
  List<Product> related(Product product, {int limit = 6}) => _products
      .where((p) => p.categoryId == product.categoryId && p.id != product.id)
      .take(limit)
      .toList(growable: false);
}
