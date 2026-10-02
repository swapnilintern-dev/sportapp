import 'package:flutter/foundation.dart';

import '../data/local/local_store.dart';
import '../data/models/engagement.dart';
import '../data/repositories/repositories.dart';

//==============================================================================
// SPOCART — Promotion controller
//------------------------------------------------------------------------------
// Owns the one offer the server says is live, and whether it should be shown.
// "Don't show again today" is remembered per promotion per day on this device,
// so turning an offer off is still the admin's job and dismissing it is the
// buyer's. Shown at most once per app launch, never over another dialog.
//==============================================================================

class PromotionController extends ChangeNotifier {
  PromotionController(this._repository, this._store);

  final CatalogRepository _repository;
  final LocalStore _store;

  static const String _storeKey = 'promotion.dismissed';

  Promotion? _promotion;
  bool _loaded = false;
  bool _shownThisLaunch = false;

  Promotion? get promotion => _promotion;
  bool get loaded => _loaded;

  /// Loads the live offer. A failure is not an error the buyer should see —
  /// there is simply no offer today.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      _promotion = await _repository.fetchActivePromotion();
    } catch (_) {
      _promotion = null;
    }
    notifyListeners();
  }

  /// The offer to show right now, or null. Returns it only once per launch, so
  /// moving between tabs cannot make it pop up again.
  Future<Promotion?> takePending() async {
    await load();
    final Promotion? p = _promotion;
    if (p == null || _shownThisLaunch) return null;
    if (p.endsAt.isBefore(DateTime.now())) return null;
    if (await _isDismissedToday(p.id)) return null;
    _shownThisLaunch = true;
    return p;
  }

  /// Remembers that this buyer closed [id] today. Tomorrow it may appear again,
  /// which is what "don't show again today" means.
  Future<void> dismissForToday(String id) async {
    try {
      await _store.writeJson(_storeKey, <String, dynamic>{
        'id': id,
        'day': _today(),
      });
    } catch (_) {
      // A device that cannot remember the dismissal simply shows it again.
    }
  }

  Future<bool> _isDismissedToday(String id) async {
    try {
      final Map<String, dynamic>? saved = await _store.readMap(_storeKey);
      if (saved == null) return false;
      return saved['id'] == id && saved['day'] == _today();
    } catch (_) {
      return false;
    }
  }

  /// Local calendar day, as YYYY-MM-DD.
  static String _today() {
    final DateTime now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}'
        '-${now.day.toString().padLeft(2, '0')}';
  }

  void reset() {
    _promotion = null;
    _loaded = false;
    _shownThisLaunch = false;
    notifyListeners();
  }
}
