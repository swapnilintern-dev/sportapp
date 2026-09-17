import 'package:flutter_test/flutter_test.dart';
import 'package:sport/data/local/local_store.dart';
import 'package:sport/data/models/account.dart';
import 'package:sport/data/models/engagement.dart';
import 'package:sport/data/models/order.dart';
import 'package:sport/data/repositories/repositories.dart';
import 'package:sport/features/bulk_upload/bulk_parser.dart';
import 'package:sport/state/cart_controller.dart';
import 'package:sport/state/catalog_controller.dart';
import 'package:sport/state/notifications_controller.dart';
import 'package:sport/state/orders_controller.dart';

const Address _address = Address(
  id: 'a1',
  contactName: 'Rohit Kumar',
  businessName: 'ABC Sports',
  line1: 'MG Road',
  city: 'Ranchi',
  state: 'Jharkhand',
  pincode: '834001',
  mobile: '9876543210',
  isDefault: true,
);

void main() {
  late CatalogController catalog;

  setUp(() async {
    catalog = CatalogController(const DemoCatalogRepository());
    await catalog.load();
  });

  group('Bulk CSV parser', () {
    test('parses the sample template with header, id, name and size', () {
      final List<BulkRow> rows = parseBulkCsv(kBulkCsvTemplate, catalog);
      expect(rows.length, 3);
      expect(rows[0].product?.id, 'ck-kashmir-willow-bat');
      expect(rows[0].quantity, 50);
      expect(rows[0].size, 'SH');
      expect(rows[1].product?.id, 'ck-ss-ball');
      expect(rows[1].size, isNull);
      expect(rows[2].product?.id, 'fb-match-ball-5');
    });

    test('keeps unmatched rows, handles quotes and semicolons', () {
      const String csv = '"Gym flooring rolls, rubber";2400\n'
          'badminton racket, 30\n';
      final List<BulkRow> rows = parseBulkCsv(csv, catalog);
      expect(rows.length, 2);
      expect(rows[0].product, isNull);
      expect(rows[0].input, 'Gym flooring rolls, rubber');
      expect(rows[0].quantity, 2400);
      expect(rows[1].product?.id, 'bd-graphite-racket');
      expect(rows[1].quantity, 30);
    });

    test('missing quantity falls back to MOQ', () {
      final List<BulkRow> rows = parseBulkCsv('Football (Size 5)', catalog);
      expect(rows.single.quantity, 20);
    });
  });

  group('Orders', () {
    test('placing an order snapshots the cart and raises a notification',
        () async {
      final MemoryStore store = MemoryStore();
      final AccountKey account = AccountKey()..mobile = '9876543210';
      final NotificationsController notifications =
          NotificationsController(DemoNotificationRepository(store, account));
      final OrdersController orders =
          OrdersController(DemoOrderRepository(store, account), notifications);
      final CartController cart = CartController(CartStorage(store), catalog);
      await cart.load();
      cart.add(catalog.productById('ck-kashmir-willow-bat')!);
      cart.add(catalog.productById('ck-ss-ball')!);

      final Order order = await orders.placeOrder(
        cart: cart,
        address: _address,
        paymentMethod: PaymentMethod.upi,
        paid: true,
      );

      expect(order.id, startsWith('SC-'));
      expect(order.invoiceId, startsWith('INV-'));
      expect(order.lines.length, 2);
      expect(order.total, closeTo(cart.total, 0.001));
      expect(order.status, OrderStatus.placed);
      expect(orders.orders.single.id, order.id);
      expect(notifications.items.single.type, NotificationType.orderPlaced);
      expect(notifications.unreadCount, 1);

      // A fresh controller over the same store sees the persisted order.
      final OrdersController again =
          OrdersController(DemoOrderRepository(store, account), notifications);
      await again.load();
      expect(again.orders.single.id, order.id);
      expect(again.totalPurchases, closeTo(order.total, 0.001));
      expect(again.pendingCount, 1);
    });

    test('pay-later orders count as outstanding until marked paid', () async {
      final MemoryStore store = MemoryStore();
      final AccountKey account = AccountKey()..mobile = '9876543210';
      final NotificationsController notifications =
          NotificationsController(DemoNotificationRepository(store, account));
      final OrdersController orders =
          OrdersController(DemoOrderRepository(store, account), notifications);
      final CartController cart = CartController(CartStorage(store), catalog);
      await cart.load();
      cart.add(catalog.productById('ft-dumbbell-set')!);

      final Order order = await orders.placeOrder(
        cart: cart,
        address: _address,
        paymentMethod: PaymentMethod.payLater,
        paid: false,
      );
      expect(orders.outstandingPayment, closeTo(order.total, 0.001));
      await orders.markPaid(order.id);
      expect(orders.outstandingPayment, 0);
    });

    test('account data is namespaced per mobile number', () async {
      final MemoryStore store = MemoryStore();
      final AccountKey account = AccountKey()..mobile = '9000000001';
      final DemoAddressRepository repo = DemoAddressRepository(store, account);
      await repo.saveAll(const [_address]);
      expect((await repo.fetchAddresses()).length, 1);
      account.mobile = '9000000002';
      expect(await repo.fetchAddresses(), isEmpty);
    });
  });
}
