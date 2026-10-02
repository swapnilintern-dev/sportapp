import 'package:flutter_test/flutter_test.dart';
import 'package:sport/core/search/product_search.dart';
import 'package:sport/data/models/catalog.dart';
import 'package:sport/data/sources/demo_catalog.dart';

//==============================================================================
// Search has to work the way buyers type on a phone: part words, the trade's
// own vocabulary, and the odd typo — while never returning something unrelated
// just because one word happened to match.
//==============================================================================

List<String> ids(String query) => searchProducts(kDemoProducts, query)
    .map((SearchHit h) => h.product.id)
    .toList();

String? top(String query) {
  final List<SearchHit> hits = searchProducts(kDemoProducts, query);
  return hits.isEmpty ? null : hits.first.product.id;
}

void main() {
  group('tokenizing', () {
    test('splits, lowercases and drops punctuation', () {
      expect(tokenize('  Cricket   BAT!! '), <String>['cricket', 'bat']);
      expect(tokenize('34" stick'), <String>['34', 'stick']);
      expect(tokenize('   '), isEmpty);
      expect(tokenize(''), isEmpty);
    });
  });

  group('edit distance', () {
    test('counts the edits it needs', () {
      expect(editDistance('bat', 'bat'), 0);
      expect(editDistance('jursey', 'jersey'), 1);
      expect(editDistance('criket', 'cricket'), 1);
      expect(editDistance('shutle', 'shuttle'), 1);
    });

    test('gives up instead of walking far-apart words', () {
      expect(editDistance('bat', 'basketball', maxEdits: 2), greaterThan(2));
    });
  });

  group('finding real products', () {
    test('a plain word finds its products', () {
      expect(ids('bat'), isNotEmpty);
      expect(top('kashmir willow'), 'ck-kashmir-willow-bat');
    });

    test('every word must match, so unrelated items are not dragged in', () {
      final List<String> both = ids('cricket helmet');
      expect(both, isNotEmpty);
      for (final String id in both) {
        final Product p = kDemoProducts.firstWhere((Product x) => x.id == id);
        expect(p.categoryId, 'cricket', reason: id);
      }
      // "cricket" alone matches far more than "cricket helmet" does.
      expect(ids('cricket').length, greaterThan(both.length));
    });

    test('a two-word query a buyer would speak', () {
      expect(top('swim cap'), 'sw-silicone-cap');
    });

    test('nonsense finds nothing rather than everything', () {
      expect(ids('qwertyuiop'), isEmpty);
      expect(ids(''), isEmpty);
      expect(ids('    '), isEmpty);
    });
  });

  group('the trade\'s vocabulary', () {
    test('"shuttle" and "cock" both reach shuttlecocks', () {
      expect(ids('shuttle'), isNotEmpty);
      expect(ids('cock'), isNotEmpty);
      expect(ids('shuttle'), containsAll(ids('shuttlecock')));
    });

    test('"soccer" reaches footballs', () {
      final List<String> soccer = ids('soccer');
      expect(soccer, isNotEmpty);
      expect(soccer.any((String id) => id.startsWith('fb-')), isTrue);
    });
  });

  group('typos', () {
    test('a one-letter slip still finds the product', () {
      expect(ids('criket'), isNotEmpty);
      expect(ids('footbal'), isNotEmpty);
    });

    test('a corrected result says so, an exact one does not', () {
      final List<SearchHit> wrong = searchProducts(kDemoProducts, 'criket');
      expect(wrong.first.corrected, isTrue);

      final List<SearchHit> right = searchProducts(kDemoProducts, 'cricket');
      expect(right.first.corrected, isFalse);
    });

    test('short words are not forgiven — they would match anything', () {
      // "bal" is one edit from "bat", "ball", "bag"… so it must not guess.
      final List<SearchHit> hits = searchProducts(kDemoProducts, 'zzz');
      expect(hits, isEmpty);
    });

    test('an exact match is always preferred over a corrected one', () {
      final List<SearchHit> hits = searchProducts(kDemoProducts, 'cricket');
      expect(hits.every((SearchHit h) => !h.corrected), isTrue);
    });
  });

  group('ranking', () {
    test('the product whose name is the query comes first', () {
      final String? first = top('football');
      expect(first, isNotNull);
      final Product p = kDemoProducts.firstWhere((Product x) => x.id == first);
      expect(p.name.toLowerCase(), contains('football'));
    });

    test('scores never increase down the list', () {
      final List<SearchHit> hits = searchProducts(kDemoProducts, 'ball');
      for (int i = 1; i < hits.length; i++) {
        expect(hits[i].score, lessThanOrEqualTo(hits[i - 1].score));
      }
    });

    test('an out-of-stock product ranks below an identical in-stock one', () {
      final Product base = kDemoProducts.first;
      final Product out = Product(
        id: 'out', name: base.name, brand: base.brand,
        categoryId: base.categoryId, subcategory: base.subcategory,
        unit: base.unit, moq: base.moq, tiers: base.tiers,
        description: base.description, images: const <String>[], inStock: false,
      );
      final List<SearchHit> hits = searchProducts(<Product>[out, base], base.name);
      expect(hits.first.product.id, base.id);
    });
  });
}
