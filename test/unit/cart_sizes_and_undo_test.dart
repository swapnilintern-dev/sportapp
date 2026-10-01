import 'package:flutter_test/flutter_test.dart';
import 'package:sport/data/local/local_store.dart';
import 'package:sport/data/models/catalog.dart';
import 'package:sport/data/models/order.dart';
import 'package:sport/data/repositories/repositories.dart';
import 'package:sport/data/sources/demo_catalog.dart';
import 'package:sport/state/cart_controller.dart';
import 'package:sport/state/catalog_controller.dart';

//==============================================================================
// Phase A: sized cart lines and remove/Undo.
//
// A sized product must never reach checkout without a size — that is what made
// the server answer "please choose a size." and the app show a generic
// "Could not place the order".
//==============================================================================

void main() {
  late CatalogController catalog;
  late CartController cart;

  // Sold in sizes (SH / 6 / 5 / 4) vs. sold as a plain unit.
  final Product sized =
      kDemoProducts.firstWhere((Product p) => p.id == 'ck-kashmir-willow-bat');
  final Product unsized =
      kDemoProducts.firstWhere((Product p) => p.sizes.isEmpty);

  setUp(() async {
    catalog = CatalogController(const DemoCatalogRepository());
    await catalog.load();
    cart = CartController(CartStorage(MemoryStore()), catalog);
    await cart.load();
  });

  group('Sized lines', () {
    test('a size-less line on a sized product is reported', () {
      cart.add(sized);
      expect(cart.requiresSize(sized), isTrue);
      expect(cart.missingSize.single.productId, sized.id);
    });

    test('products without sizes are never reported', () {
      cart.add(unsized);
      expect(cart.requiresSize(unsized), isFalse);
      expect(cart.missingSize, isEmpty);
    });

    test('setSize fixes the line and clears the warning', () {
      cart.add(sized);
      cart.setSize(cart.lines.single, 'SH');
      expect(cart.lines.single.size, 'SH');
      expect(cart.missingSize, isEmpty);
    });

    test('setSize merges into a line that already holds that size', () {
      cart.add(sized, size: 'SH', qty: 12);
      cart.add(sized); // legacy size-less line
      expect(cart.lineCount, 2);

      cart.setSize(cart.lines.last, 'SH');
      expect(cart.lineCount, 1);
      expect(cart.lines.single.size, 'SH');
      expect(cart.lines.single.quantity, 12 + sized.moq);
    });

    test('order lines carry the size through to the snapshot', () {
      cart.add(sized, size: '6');
      expect(cart.toOrderLines().single.size, '6');
    });
  });

  group('Remove and Undo', () {
    test('remove returns the position and restore puts it back there', () {
      cart.add(unsized);
      cart.add(sized, size: 'SH');
      cart.add(sized, size: '6');
      final CartLine middle = cart.lines[1];

      final int at = cart.remove(middle);
      expect(at, 1);
      expect(cart.lineCount, 2);

      cart.restore(middle, at);
      expect(cart.lineCount, 3);
      expect(cart.lines[1].key, middle.key);
    });

    test('removing an unknown line reports -1 and changes nothing', () {
      cart.add(unsized);
      final CartLine gone = cart.lines.single;
      cart.remove(gone);
      expect(cart.remove(gone), -1);
      expect(cart.isEmpty, isTrue);
    });

    test('restore merges when the same line was re-added meanwhile', () {
      cart.add(sized, size: 'SH', qty: 20);
      final CartLine removed = cart.lines.single;
      final int at = cart.remove(removed);

      cart.add(sized, size: 'SH', qty: 5);
      cart.restore(removed, at);

      expect(cart.lineCount, 1);
      expect(cart.lines.single.quantity, 25);
    });

    test('restore clamps a stale position instead of throwing', () {
      cart.add(unsized);
      final CartLine line = cart.lines.single;
      cart.remove(line);
      cart.restore(line, 99);
      expect(cart.lines.single.key, line.key);
    });

    test('totals and below-MOQ follow the restored line', () {
      cart.add(sized, size: 'SH');
      final double full = cart.total;
      final CartLine line = cart.lines.single;

      final int at = cart.remove(line);
      expect(cart.total, 0);

      cart.restore(line, at);
      expect(cart.total, full);
      expect(cart.belowMoq, isEmpty);
    });
  });
}
