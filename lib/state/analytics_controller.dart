import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/local/local_store.dart';
import '../data/repositories/repositories.dart';

//==============================================================================
// SPOCART — Analytics
//------------------------------------------------------------------------------
// Reports what the app did, in batches, so the business can see how many people
// use SPOCART and where they stop in the cart. It is deliberately dumb: it
// counts, and it never carries anything a buyer typed or anything that
// identifies a person. The device id identifies an install so an anonymous
// visitor is counted once, and nothing else.
//
// Failing to report is never an error the buyer sees — a dropped batch costs a
// count, not an order.
//==============================================================================

/// The only events the app reports. The server drops anything it does not
/// recognise, so this list and the server's have to agree.
enum AppEvent {
  appOpen,
  productView,
  search,
  addToCart,
  checkoutStart,
  orderPlaced;

  String get wire => name;
}

class AnalyticsController extends ChangeNotifier {
  AnalyticsController(this._repository, this._store);

  final AnalyticsRepository _repository;
  final LocalStore _store;

  static const String _deviceKey = 'analytics.deviceId';

  /// Events are held briefly so a burst of taps is one request, not six.
  static const Duration _flushAfter = Duration(seconds: 10);

  /// A hard cap, so a long offline session cannot grow without limit.
  static const int _maxQueued = 100;

  final List<Map<String, dynamic>> _queue = <Map<String, dynamic>>[];
  Timer? _timer;
  String? _deviceId;
  bool _sending = false;

  /// Switched off for the on-device demo backend, which has nowhere to report.
  bool enabled = true;

  /// A random id for this install, kept on the device. It says which install an
  /// event came from, never who is holding the phone.
  Future<String> deviceId() async {
    final String? cached = _deviceId;
    if (cached != null) return cached;
    try {
      final List<String>? saved = await _store.readStrings(_deviceKey);
      if (saved != null && saved.isNotEmpty && saved.first.length >= 8) {
        return _deviceId = saved.first;
      }
    } catch (_) {
      // A device that cannot remember it gets a new one each launch; that
      // overcounts slightly and is better than failing.
    }
    final String fresh = _randomId();
    _deviceId = fresh;
    try {
      await _store.writeStrings(_deviceKey, <String>[fresh]);
    } catch (_) {
      // Not fatal: see above.
    }
    return fresh;
  }

  static String _randomId() {
    const String alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final Random random = Random.secure();
    return List<String>.generate(24, (_) => alphabet[random.nextInt(alphabet.length)])
        .join();
  }

  /// Queues one event. [meta] is reduced to the whole numbers the server keeps,
  /// so nothing a buyer typed can leave the phone even by accident.
  void log(
    AppEvent event, {
    String? productId,
    String? orderId,
    int? results,
    int? queryLength,
    int? quantity,
  }) {
    if (!enabled) return;
    if (_queue.length >= _maxQueued) _queue.removeAt(0);

    _queue.add(<String, dynamic>{
      'name': event.wire,
      'at': DateTime.now().toUtc().toIso8601String(),
      'productId': ?productId,
      'orderId': ?orderId,
      'meta': <String, int>{
        'results': ?results,
        'queryLength': ?queryLength,
        'quantity': ?quantity,
      },
    });

    _timer ??= Timer(_flushAfter, flush);
  }

  /// Sends whatever is queued. Safe to call at any time; a failure puts the
  /// events back so the next attempt carries them.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (!enabled || _sending || _queue.isEmpty) return;

    final List<Map<String, dynamic>> batch =
        List<Map<String, dynamic>>.of(_queue);
    _queue.clear();
    _sending = true;
    try {
      await _repository.report(
        deviceId: await deviceId(),
        platform: _platform,
        events: batch,
      );
    } catch (_) {
      // Put them back, oldest first, without letting the queue grow past its cap.
      _queue.insertAll(0, batch);
      if (_queue.length > _maxQueued) {
        _queue.removeRange(0, _queue.length - _maxQueued);
      }
    } finally {
      _sending = false;
    }
  }

  String get _platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  /// Queued events only, for tests and for a "what is pending" check.
  @visibleForTesting
  int get pending => _queue.length;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
