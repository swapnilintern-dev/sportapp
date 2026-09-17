import 'package:flutter_test/flutter_test.dart';
import 'package:sport/core/utils/formatters.dart';
import 'package:sport/core/utils/validators.dart';
import 'package:sport/data/local/local_store.dart';
import 'package:sport/data/models/catalog.dart';
import 'package:sport/data/repositories/repositories.dart';
import 'package:sport/data/sources/demo_catalog.dart';
import 'package:sport/state/cart_controller.dart';
import 'package:sport/state/catalog_controller.dart';

void main() {
  group('Tiered pricing', () {
    final Product bat =
        kDemoProducts.firstWhere((p) => p.id == 'ck-kashmir-willow-bat');

    test('price drops across slabs', () {
      expect(bat.priceForQuantity(10), 1800);
      expect(bat.priceForQuantity(49), 1800);
      expect(bat.priceForQuantity(50), 1600);
      expect(bat.priceForQuantity(120), 1400);
      expect(bat.priceForQuantity(500), 1200);
    });

    test('range labels match the design table', () {
      expect(bat.tierRangeLabel(0), '10 - 49');
      expect(bat.tierRangeLabel(1), '50 - 99');
      expect(bat.tierRangeLabel(2), '100 - 499');
      expect(bat.tierRangeLabel(3), '500+');
    });

    test('every demo product has ascending slabs starting at its MOQ', () {
      for (final Product p in kDemoProducts) {
        expect(p.tiers.first.minQty, p.moq, reason: p.id);
        for (int i = 1; i < p.tiers.length; i++) {
          expect(p.tiers[i].minQty, greaterThan(p.tiers[i - 1].minQty));
          expect(p.tiers[i].unitPrice, lessThan(p.tiers[i - 1].unitPrice));
        }
      }
    });

    test('demo product ids are unique and categories exist', () {
      final Set<String> ids = kDemoProducts.map((p) => p.id).toSet();
      expect(ids.length, kDemoProducts.length);
      final Set<String> categories = kDemoCategories.map((c) => c.id).toSet();
      for (final Product p in kDemoProducts) {
        expect(categories.contains(p.categoryId), isTrue, reason: p.id);
      }
    });
  });

  group('Cart', () {
    late CatalogController catalog;
    late CartController cart;

    setUp(() async {
      catalog = CatalogController(const DemoCatalogRepository());
      await catalog.load();
      cart = CartController(CartStorage(MemoryStore()), catalog);
      await cart.load();
    });

    test('first add starts at MOQ and totals include 18% GST', () {
      final Product bat = catalog.productById('ck-kashmir-willow-bat')!;
      cart.add(bat);
      expect(cart.quantityOf(bat.id), bat.moq);
      expect(cart.subtotal, bat.moq * bat.priceForQuantity(bat.moq));
      expect(cart.gst, closeTo(cart.subtotal * 0.18, 0.001));
      expect(cart.total, closeTo(cart.subtotal * 1.18, 0.001));
    });

    test('sizes are separate lines; quantity changes re-price the slab', () {
      final Product bat = catalog.productById('ck-kashmir-willow-bat')!;
      cart.add(bat, size: 'SH');
      cart.add(bat, size: '6');
      expect(cart.lineCount, 2);
      final line = cart.lineFor(bat.id, size: 'SH')!;
      cart.setQuantity(line, 60);
      expect(cart.unitPrice(cart.lineFor(bat.id, size: 'SH')!), 1600);
      cart.setQuantity(cart.lineFor(bat.id, size: 'SH')!, 0);
      expect(cart.lineCount, 1);
    });

    test('below-MOQ lines are reported and order lines snapshot prices', () {
      final Product ball = catalog.productById('ck-ss-ball')!;
      cart.add(ball);
      cart.setQuantity(cart.lineFor(ball.id)!, 5);
      expect(cart.belowMoq.length, 1);
      cart.setQuantity(cart.lineFor(ball.id)!, 96);
      expect(cart.belowMoq, isEmpty);
      final lines = cart.toOrderLines();
      expect(lines.single.unitPrice, 350);
      expect(lines.single.lineTotal, 350 * 96);
    });

    test('cart persists through the store', () async {
      final MemoryStore store = MemoryStore();
      final CartController first = CartController(CartStorage(store), catalog);
      await first.load();
      first.add(catalog.productById('fb-match-ball-5')!);
      // Persistence is fire-and-forget; let it flush.
      await Future<void>.delayed(Duration.zero);
      final CartController second = CartController(CartStorage(store), catalog);
      await second.load();
      expect(second.quantityOf('fb-match-ball-5'), 20);
    });
  });

  group('Formatters & validators', () {
    test('Indian rupee grouping', () {
      expect(formatInr(0), '₹0');
      expect(formatInr(999), '₹999');
      expect(formatInr(25960), '₹25,960');
      expect(formatInr(245000), '₹2,45,000');
      expect(formatInr(10000000), '₹1,00,00,000');
      expect(formatInrRange(1200, 1800), '₹1,200 - ₹1,800');
      expect(formatInrRange(650, 650), '₹650');
    });

    test('mobile formatting', () {
      expect(formatIndianMobile('9876543210'), '+91 98765 43210');
    });

    test('GSTIN validation', () {
      expect(Validators.gstin('27AACCA1234F1Z5'), isNull);
      expect(Validators.gstin('27aacca1234f1z5'), isNull);
      expect(Validators.gstin('1234'), isNotNull);
      expect(Validators.gstin(''), isNotNull);
    });

    test('mobile / email / pincode validation', () {
      expect(Validators.mobile('9876543210'), isNull);
      expect(Validators.mobile('1234567890'), isNotNull);
      expect(Validators.email('rohit@abcsports.in'), isNull);
      expect(Validators.email('rohit@'), isNotNull);
      expect(Validators.pincode('834001'), isNull);
      expect(Validators.pincode('0123'), isNotNull);
    });
  });

  group('Demo auth', () {
    test('OTP round trip and session restore', () async {
      final MemoryStore store = MemoryStore();
      final DemoAuthRepository auth = DemoAuthRepository(store, AccountKey());
      final OtpChallenge challenge = await auth.sendOtp('9876543210');
      expect(challenge.demoCode, isNotNull);
      expect(
        () => auth.verifyOtp('9876543210', '000000'),
        throwsA(isA<AppException>()),
      );
      final session = await auth.verifyOtp('9876543210', challenge.demoCode!);
      expect(session.mobile, '9876543210');
      expect(session.isRegistered, isFalse);
      final restored = await auth.restoreSession();
      expect(restored?.mobile, '9876543210');
      await auth.signOut();
      expect(await auth.restoreSession(), isNull);
    });
  });
}
