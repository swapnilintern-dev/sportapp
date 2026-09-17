import 'package:flutter/foundation.dart';

import '../data/models/engagement.dart';
import '../data/repositories/repositories.dart';

//==============================================================================
// SPOCART — Notifications controller
//------------------------------------------------------------------------------
// The in-app inbox. Entries are generated from real events (order placed,
// status changes, quote submitted, welcome) and persisted locally.
//==============================================================================

class NotificationsController extends ChangeNotifier {
  NotificationsController(this._repository);

  final NotificationRepository _repository;

  List<AppNotification> _items = <AppNotification>[];
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  List<AppNotification> get items => List<AppNotification>.unmodifiable(_items);
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;
  int get unreadCount => _items.where((n) => !n.read).length;

  Future<void> load({bool force = false}) async {
    if (_loading || (_loaded && !force)) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _items = List<AppNotification>.of(await _repository.fetchAll());
      _items.sort((a, b) => b.time.compareTo(a.time));
      _loaded = true;
    } catch (_) {
      _error = 'Could not load notifications.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> push({
    required NotificationType type,
    required String title,
    required String body,
    String? orderId,
    String? productId,
    String? quoteId,
  }) async {
    await load();
    _items.insert(
      0,
      AppNotification(
        id: Ids.local(),
        type: type,
        title: title,
        body: body,
        time: DateTime.now(),
        orderId: orderId,
        productId: productId,
        quoteId: quoteId,
      ),
    );
    notifyListeners();
    await _repository.saveAll(_items);
  }

  /// True when an unread/read entry already exists for this order + type, so
  /// status polling never duplicates "Order Shipped".
  bool hasOrderEvent(String orderId, NotificationType type) =>
      _items.any((n) => n.orderId == orderId && n.type == type);

  Future<void> markRead(String id) async {
    final int i = _items.indexWhere((n) => n.id == id);
    if (i < 0 || _items[i].read) return;
    _items[i] = _items[i].copyWith(read: true);
    notifyListeners();
    await _repository.saveAll(_items);
  }

  Future<void> markAllRead() async {
    if (unreadCount == 0) return;
    _items = _items.map((n) => n.copyWith(read: true)).toList();
    notifyListeners();
    await _repository.saveAll(_items);
  }

  Future<void> clearAll() async {
    _items = <AppNotification>[];
    notifyListeners();
    await _repository.saveAll(_items);
  }

  void reset() {
    _items = <AppNotification>[];
    _loaded = false;
    notifyListeners();
  }
}
