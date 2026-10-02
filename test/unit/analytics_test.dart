import 'package:flutter_test/flutter_test.dart';
import 'package:sport/data/local/local_store.dart';
import 'package:sport/data/repositories/repositories.dart';
import 'package:sport/state/analytics_controller.dart';

//==============================================================================
// Analytics must count without ever carrying anything a buyer typed, and a lost
// batch must cost a count rather than an order.
//==============================================================================

class _FakeAnalyticsRepository implements AnalyticsRepository {
  bool fail = false;
  int calls = 0;
  final List<List<Map<String, dynamic>>> batches = <List<Map<String, dynamic>>>[];
  String? lastDeviceId;

  @override
  Future<void> report({
    required String deviceId,
    required String platform,
    required List<Map<String, dynamic>> events,
  }) async {
    calls++;
    lastDeviceId = deviceId;
    if (fail) throw const AppException('offline');
    batches.add(events);
  }
}

void main() {
  late _FakeAnalyticsRepository repo;
  late MemoryStore store;
  late AnalyticsController analytics;

  setUp(() {
    repo = _FakeAnalyticsRepository();
    store = MemoryStore();
    analytics = AnalyticsController(repo, store);
  });

  group('the device id', () {
    test('is random, long enough, and the same on the next launch', () async {
      final String first = await analytics.deviceId();
      expect(first.length, greaterThanOrEqualTo(8));

      // A fresh controller on the same device must reuse it, or every launch
      // would look like a new visitor.
      final AnalyticsController next = AnalyticsController(repo, store);
      expect(await next.deviceId(), first);
    });

    test('two installs are two different ids', () async {
      final String a = await analytics.deviceId();
      final String b = await AnalyticsController(repo, MemoryStore()).deviceId();
      expect(a, isNot(b));
    });
  });

  group('what leaves the phone', () {
    test('carries counts and ids, never text', () async {
      analytics.log(AppEvent.search, results: 0, queryLength: 17);
      analytics.log(AppEvent.addToCart, productId: 'bat-1', quantity: 10);
      await analytics.flush();

      final List<Map<String, dynamic>> sent = repo.batches.single;
      expect(sent.length, 2);
      expect(sent.first['meta'], <String, int>{'results': 0, 'queryLength': 17});
      expect(sent.last['productId'], 'bat-1');

      // The only thing log() can put in meta is a count, and only under these
      // names — there is no parameter through which text could travel.
      const Set<String> allowed = <String>{'results', 'queryLength', 'quantity'};
      for (final Map<String, dynamic> e in sent) {
        final Map<String, dynamic> meta = e['meta'] as Map<String, dynamic>;
        expect(meta.keys.toSet().difference(allowed), isEmpty);
        for (final Object? value in meta.values) {
          expect(value, isA<int>());
        }
        // The event's own fields are a name, a timestamp and known ids.
        expect(
          e.keys.toSet().difference(
              <String>{'name', 'at', 'productId', 'orderId', 'meta'}),
          isEmpty,
        );
      }
    });

    test('every event name matches one the server accepts', () async {
      for (final AppEvent e in AppEvent.values) {
        analytics.log(e);
      }
      await analytics.flush();
      final List<String> names = repo.batches.single
          .map((Map<String, dynamic> e) => e['name'] as String)
          .toList();
      expect(names, <String>[
        'appOpen', 'productView', 'search', 'addToCart', 'checkoutStart', 'orderPlaced',
      ]);
    });
  });

  group('batching', () {
    test('many events go in one request', () async {
      for (int i = 0; i < 6; i++) {
        analytics.log(AppEvent.productView, productId: 'p$i');
      }
      await analytics.flush();
      expect(repo.calls, 1);
      expect(repo.batches.single.length, 6);
    });

    test('flushing with nothing queued sends nothing', () async {
      await analytics.flush();
      expect(repo.calls, 0);
    });

    test('a failed send keeps the events for the next attempt', () async {
      repo.fail = true;
      analytics.log(AppEvent.appOpen);
      await analytics.flush();
      expect(repo.calls, 1);
      expect(analytics.pending, 1, reason: 'kept, not thrown away');

      repo.fail = false;
      await analytics.flush();
      expect(repo.batches.single.length, 1);
      expect(analytics.pending, 0);
    });

    test('a long offline session cannot grow without limit', () async {
      repo.fail = true;
      for (int i = 0; i < 250; i++) {
        analytics.log(AppEvent.productView, productId: 'p$i');
      }
      await analytics.flush();
      expect(analytics.pending, lessThanOrEqualTo(100));
    });

    test('switched off, it queues nothing at all', () async {
      analytics.enabled = false;
      for (int i = 0; i < 10; i++) {
        analytics.log(AppEvent.appOpen);
      }
      await analytics.flush();
      expect(analytics.pending, 0);
      expect(repo.calls, 0);
    });
  });
}
