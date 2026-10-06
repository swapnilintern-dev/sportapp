import 'package:flutter_test/flutter_test.dart';
import 'package:sport/data/local/local_store.dart';
import 'package:sport/data/models/catalog.dart';
import 'package:sport/data/models/engagement.dart';
import 'package:sport/data/repositories/repositories.dart';
import 'package:sport/data/sources/demo_catalog.dart';
import 'package:sport/state/promotion_controller.dart';

//==============================================================================
// Offers and deals must never overstate anything: an offer shows once per
// launch and obeys "don't show again today", and a deal only claims a saving
// or a stock count the server actually recorded.
//==============================================================================

class _FakeCatalogRepository implements CatalogRepository {
  _FakeCatalogRepository({this.promotion, this.fail = false});

  Promotion? promotion;
  bool fail;
  int calls = 0;

  @override
  Future<Promotion?> fetchActivePromotion() async {
    calls++;
    if (fail) throw const AppException('offers are down');
    return promotion;
  }

  @override
  Future<List<ProductCategory>> fetchCategories() async => kDemoCategories;
  @override
  Future<List<Product>> fetchProducts() async => kDemoProducts;
  @override
  Future<List<String>> fetchBestSellerIds({int limit = 10}) async => const <String>[];
  @override
  Future<List<Deal>> fetchDeals({int limit = 20}) async => const <Deal>[];
  @override
  Future<List<Product>> fetchNewLaunches({int limit = 10}) async => const <Product>[];

  // Not what these tests are about: the demo catalogue carries no barcodes.
  @override
  Future<Product> productByBarcode(String code) async =>
      throw const AppException('No SPOCART product carries that barcode.');

  // Not what these tests are about.
  @override
  Future<AssistResult> assist(String query) async => AssistResult.empty;
}

Promotion _promotion({
  String id = 'promo-1',
  Duration endsIn = const Duration(days: 7),
  PromotionLink link = PromotionLink.none,
  String? target,
}) =>
    Promotion(
      id: id,
      title: 'Diwali Bulk Sale',
      body: 'Extra 10% off above 100 units.',
      link: link,
      linkTarget: target,
      endsAt: DateTime.now().add(endsIn),
    );

void main() {
  group('Offer popup rules', () {
    test('a live offer is handed over exactly once per launch', () async {
      final _FakeCatalogRepository repo =
          _FakeCatalogRepository(promotion: _promotion());
      final PromotionController c = PromotionController(repo, MemoryStore());

      expect((await c.takePending())?.id, 'promo-1');
      expect(await c.takePending(), isNull, reason: 'second ask in the same launch');
      expect(await c.takePending(), isNull);
      expect(repo.calls, 1, reason: 'the server is asked once, not per tab');
    });

    test('"don\'t show again today" is remembered across launches', () async {
      final MemoryStore store = MemoryStore();
      final _FakeCatalogRepository repo =
          _FakeCatalogRepository(promotion: _promotion());

      final PromotionController first = PromotionController(repo, store);
      expect(await first.takePending(), isNotNull);
      await first.dismissForToday('promo-1');

      // A fresh launch, same device, same day.
      final PromotionController second = PromotionController(repo, store);
      expect(await second.takePending(), isNull);
    });

    test('dismissing one offer does not hide a different one', () async {
      final MemoryStore store = MemoryStore();
      final PromotionController first = PromotionController(
          _FakeCatalogRepository(promotion: _promotion()), store);
      await first.takePending();
      await first.dismissForToday('promo-1');

      final PromotionController second = PromotionController(
          _FakeCatalogRepository(promotion: _promotion(id: 'promo-2')), store);
      expect((await second.takePending())?.id, 'promo-2');
    });

    test('an offer that has already ended is never shown', () async {
      final PromotionController c = PromotionController(
        _FakeCatalogRepository(
            promotion: _promotion(endsIn: const Duration(seconds: -1))),
        MemoryStore(),
      );
      expect(await c.takePending(), isNull);
    });

    test('no offer, and a failure to fetch one, both mean nothing is shown',
        () async {
      final PromotionController none =
          PromotionController(_FakeCatalogRepository(), MemoryStore());
      expect(await none.takePending(), isNull);

      final PromotionController broken = PromotionController(
          _FakeCatalogRepository(promotion: _promotion(), fail: true),
          MemoryStore());
      expect(await broken.takePending(), isNull);
      expect(broken.promotion, isNull);
    });

    test('signing out forgets the offer so the next buyer is asked again',
        () async {
      final _FakeCatalogRepository repo =
          _FakeCatalogRepository(promotion: _promotion());
      final PromotionController c = PromotionController(repo, MemoryStore());
      await c.takePending();
      expect(repo.calls, 1);

      c.reset();
      expect((await c.takePending())?.id, 'promo-1');
      expect(repo.calls, 2);
    });

    test('the action label follows where the offer leads', () {
      expect(_promotion(link: PromotionLink.product, target: 'p').actionLabel,
          'View Product');
      expect(_promotion(link: PromotionLink.category, target: 'c').actionLabel,
          'Shop Now');
      expect(
          _promotion(link: PromotionLink.url, target: 'https://x.test').actionLabel,
          'Know More');
      expect(_promotion().hasAction, isFalse);
      expect(_promotion(link: PromotionLink.url).hasAction, isFalse,
          reason: 'a link type with no target is not an action');
    });
  });

  group('Deal', () {
    Deal deal({double? previous, int? stock}) => Deal(
          product: kDemoProducts.first,
          currentPrice: 1500,
          previousPrice: previous,
          stockLeft: stock,
        );

    test('a recorded drop gives the saving and the percent', () {
      final Deal d = deal(previous: 1800);
      expect(d.hasDrop, isTrue);
      expect(d.saving, 300);
      expect(d.savingPercent, 17);
    });

    test('no recorded previous price means no claimed saving', () {
      final Deal d = deal(stock: 6);
      expect(d.hasDrop, isFalse);
      expect(d.saving, 0);
      expect(d.savingPercent, 0);
      expect(d.isLowStock, isTrue);
    });

    test('a price that went up is not a drop', () {
      expect(deal(previous: 1200).hasDrop, isFalse);
    });

    test('untracked stock says nothing about quantity', () {
      expect(deal(previous: 1800).isLowStock, isFalse);
      expect(deal(stock: 0).isLowStock, isFalse);
    });

    test('parses what the server sends', () {
      final Deal d = Deal.fromJson(<String, dynamic>{
        'id': 'ck-ss-ball',
        'name': 'SS Cricket Ball',
        'brand': 'SS',
        'categoryId': 'cricket',
        'subcategory': 'Balls',
        'unit': 'pc',
        'moq': 24,
        'description': '',
        'images': <String>[],
        'tiers': <Map<String, dynamic>>[
          {'minQty': 24, 'unitPrice': 320},
        ],
        'currentPrice': 320,
        'previousPrice': 400,
        'stockLeft': 12,
      });
      expect(d.product.id, 'ck-ss-ball');
      expect(d.savingPercent, 20);
      expect(d.stockLeft, 12);
    });
  });

  group('Product video', () {
    Product parse(Map<String, dynamic> extra) => Product.fromJson(<String, dynamic>{
          'id': 'p',
          'name': 'P',
          'brand': 'B',
          'categoryId': 'cricket',
          'subcategory': 'S',
          'unit': 'pc',
          'moq': 1,
          'description': '',
          'images': <String>[],
          'tiers': <Map<String, dynamic>>[
            {'minQty': 1, 'unitPrice': 100},
          ],
          ...extra,
        });

    test('a product with a video carries its thumbnail too', () {
      final Product p = parse(<String, dynamic>{
        'videoUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'videoThumbnailUrl': 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      });
      expect(p.hasVideo, isTrue);
      expect(p.videoThumbnailUrl, contains('dQw4w9WgXcQ'));
    });

    test('a product without one claims nothing', () {
      final Product p = parse(<String, dynamic>{});
      expect(p.hasVideo, isFalse);
      expect(p.videoUrl, isNull);
      expect(p.videoThumbnailUrl, isNull);
      expect(p.stockLeft, isNull);
    });
  });
}
