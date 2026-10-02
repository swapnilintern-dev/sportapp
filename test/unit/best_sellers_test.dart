import 'package:flutter_test/flutter_test.dart';
import 'package:sport/data/models/catalog.dart';
import 'package:sport/data/models/engagement.dart';
import 'package:sport/data/repositories/repositories.dart';
import 'package:sport/data/sources/demo_catalog.dart';
import 'package:sport/state/catalog_controller.dart';

//==============================================================================
// Best sellers come from real sales. The app must rank by what the server says,
// fall back to the catalogue's own flag on a store with no history, and never
// badge everything as Trending.
//==============================================================================

/// Serves the demo catalogue with a ranking we control.
class _FakeCatalogRepository implements CatalogRepository {
  _FakeCatalogRepository(this.ranking, {this.failRanking = false});

  final List<String> ranking;
  final bool failRanking;
  int rankingCalls = 0;
  int? lastLimit;

  @override
  Future<List<ProductCategory>> fetchCategories() async => kDemoCategories;

  @override
  Future<List<Product>> fetchProducts() async => kDemoProducts;

  @override
  Future<List<String>> fetchBestSellerIds({int limit = 10}) async {
    rankingCalls++;
    lastLimit = limit;
    if (failRanking) throw const AppException('ranking is down');
    return ranking.take(limit).toList();
  }

  // The other shelves are not what these tests are about; they stay empty so a
  // failure here could only come from the ranking.
  @override
  Future<List<Deal>> fetchDeals({int limit = 20}) async => const <Deal>[];

  @override
  Future<List<Product>> fetchNewLaunches({int limit = 10}) async =>
      const <Product>[];

  @override
  Future<Promotion?> fetchActivePromotion() async => null;

  // Not what these tests are about: the demo catalogue carries no barcodes.
  @override
  Future<Product> productByBarcode(String code) async =>
      throw const AppException('No SPOCART product carries that barcode.');
}

Future<CatalogController> _loaded(_FakeCatalogRepository repo) async {
  final CatalogController c = CatalogController(repo);
  await c.load();
  return c;
}

void main() {
  const String ball = 'ck-ss-ball';
  const String football = 'fb-match-ball-5';
  const String helmet = 'ck-batting-helmet';

  test('best sellers follow the server ranking, in order', () async {
    final CatalogController c =
        await _loaded(_FakeCatalogRepository(<String>[helmet, ball, football]));
    expect(c.bestSellers.map((Product p) => p.id).toList(),
        <String>[helmet, ball, football]);
  });

  test('ids the catalogue does not carry are skipped, not rendered as holes',
      () async {
    final CatalogController c = await _loaded(
        _FakeCatalogRepository(<String>[ball, 'deleted-product', football]));
    expect(c.bestSellers.map((Product p) => p.id).toList(),
        <String>[ball, football]);
  });

  test('a store with no sales yet falls back to the popular flag', () async {
    final CatalogController c =
        await _loaded(_FakeCatalogRepository(const <String>[]));
    expect(c.bestSellers, isNotEmpty);
    expect(c.bestSellers, equals(c.popular));
  });

  test('a ranking failure never breaks the catalogue', () async {
    final _FakeCatalogRepository repo =
        _FakeCatalogRepository(const <String>[], failRanking: true);
    final CatalogController c = await _loaded(repo);
    expect(repo.rankingCalls, 1);
    expect(c.loaded, isTrue);
    expect(c.error, isNull);
    expect(c.products, isNotEmpty);
    expect(c.bestSellers, equals(c.popular));
  });

  group('Trending badge', () {
    test('marks only the top few sellers', () async {
      final List<String> ranking = kDemoProducts
          .take(CatalogController.trendingCount + 3)
          .map((Product p) => p.id)
          .toList();
      final CatalogController c = await _loaded(_FakeCatalogRepository(ranking));

      for (final String id in ranking.take(CatalogController.trendingCount)) {
        expect(c.isTrending(id), isTrue, reason: id);
      }
      for (final String id in ranking.skip(CatalogController.trendingCount)) {
        expect(c.isTrending(id), isFalse, reason: id);
      }
    });

    test('nothing is trending while there is no ranking', () async {
      final CatalogController c =
          await _loaded(_FakeCatalogRepository(const <String>[]));
      for (final Product p in c.popular) {
        expect(c.isTrending(p.id), isFalse, reason: p.id);
      }
    });
  });

  test('the demo backend ranks its popular products', () async {
    const DemoCatalogRepository demo = DemoCatalogRepository();
    final List<String> ids = await demo.fetchBestSellerIds(limit: 3);
    expect(ids.length, lessThanOrEqualTo(3));
    for (final String id in ids) {
      expect(kDemoProducts.firstWhere((Product p) => p.id == id).popular, isTrue);
    }
  });
}
