import 'package:flutter/foundation.dart';

import '../core/search/product_search.dart';
import '../data/models/catalog.dart';
import '../data/models/engagement.dart';
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
  List<Deal> _deals = const <Deal>[];
  List<Product> _newLaunches = const <Product>[];
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
      // The shelves are extras on top of the catalogue: if any of them fails
      // the catalogue still loads, and Home simply hides that section.
      await Future.wait<void>(<Future<void>>[
        _repository
            .fetchBestSellerIds(limit: 10)
            .then((List<String> ids) => _bestSellerIds = ids)
            .catchError((_) => _bestSellerIds = const <String>[]),
        _repository
            .fetchDeals(limit: 20)
            .then((List<Deal> d) => _deals = d)
            .catchError((_) => _deals = const <Deal>[]),
        _repository
            .fetchNewLaunches(limit: 10)
            .then((List<Product> p) => _newLaunches = p)
            .catchError((_) => _newLaunches = const <Product>[]),
      ]);
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

  /// Products with a price the seller actually dropped, or stock running low.
  /// Empty is normal — Home hides the shelf rather than showing a fake offer.
  List<Deal> get deals => _deals;

  /// Newest products first. Used for the New Launches rail.
  List<Product> get newLaunches => _newLaunches;

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

  /// Ranked search over the loaded catalogue: token matching, the trade's own
  /// vocabulary, and typo forgiveness when nothing matched exactly.
  List<Product> search(String query) =>
      searchHits(query).map((SearchHit h) => h.product).toList(growable: false);

  /// The same results with their reason, for a screen that wants to say
  /// "showing results for the closest match".
  List<SearchHit> searchHits(String query) => searchProducts(_products, query);

  /// True when the results only came back after forgiving a typo.
  bool searchWasCorrected(String query) {
    final List<SearchHit> hits = searchHits(query);
    return hits.isNotEmpty && hits.first.corrected;
  }

  /// Resolves a scanned barcode to a product. The server decides; a code no
  /// product carries throws, and the caller reports that rather than guessing.
  Future<Product> productByBarcode(String code) =>
      _repository.productByBarcode(code);

  /// Plain-language product help, answered by the server.
  Future<AssistResult> assist(String query) => _repository.assist(query);

  /// Products a buyer might also want, excluding [product] itself.
  List<Product> related(Product product, {int limit = 6}) => _products
      .where((p) => p.categoryId == product.categoryId && p.id != product.id)
      .take(limit)
      .toList(growable: false);
}
