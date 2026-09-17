import 'package:flutter/foundation.dart';

import '../data/models/engagement.dart';
import '../data/repositories/repositories.dart';

//==============================================================================
// SPOCART — Notifications controller
//------------------------------------------------------------------------------
// The in-app inbox. With the real backend the server writes every entry; in
// demo mode ([localEvents]) the controllers write them on-device.
//==============================================================================

class NotificationsController extends ChangeNotifier {
  NotificationsController(this._repository, {this.localEvents = false});

  final NotificationRepository _repository;

  /// True in demo mode: order / quote events create notifications locally.
  final bool localEvents;

  List<AppNotification> _items = <AppNotification>[];
  int _unread = 0;
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  List<AppNotification> get items => List<AppNotification>.unmodifiable(_items);
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;
  int get unreadCount => _unread;

  Future<void> load({bool force = false}) async {
    if (_loading || (_loaded && !force)) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final NotificationPage page = await _repository.fetchAll();
      _items = List<AppNotification>.of(page.items);
      _unread = page.unreadCount;
      _loaded = true;
    } on AppException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load notifications.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Demo mode only; a no-op against the real backend.
  Future<void> pushLocal({
    required NotificationType type,
    required String title,
    required String body,
    String? orderId,
    String? productId,
    String? quoteId,
  }) async {
    if (!localEvents) return;
    final AppNotification n = AppNotification(
      id: Ids.local(),
      type: type,
      title: title,
      body: body,
      time: DateTime.now(),
      orderId: orderId,
      productId: productId,
      quoteId: quoteId,
    );
    await _repository.push(n);
    _items.insert(0, n);
    _unread++;
    _loaded = true;
    notifyListeners();
  }

  bool hasOrderEvent(String orderId, NotificationType type) =>
      _items.any((n) => n.orderId == orderId && n.type == type);

  Future<void> markRead(String id) async {
    final int i = _items.indexWhere((n) => n.id == id);
    if (i < 0 || _items[i].read) return;
    _items[i] = _items[i].copyWith(read: true);
    _unread = (_unread - 1).clamp(0, _items.length);
    notifyListeners();
    await _repository.markRead(id);
  }

  Future<void> markAllRead() async {
    if (_unread == 0) return;
    _items = _items.map((n) => n.copyWith(read: true)).toList();
    _unread = 0;
    notifyListeners();
    await _repository.markAllRead();
  }

  Future<void> clearAll() async {
    _items = <AppNotification>[];
    _unread = 0;
    notifyListeners();
    await _repository.clearAll();
  }

  void reset() {
    _items = <AppNotification>[];
    _unread = 0;
    _loaded = false;
    notifyListeners();
  }
}
