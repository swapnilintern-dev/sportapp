import 'package:flutter/foundation.dart';

import '../data/models/engagement.dart';
import '../data/models/order.dart';
import '../data/repositories/repositories.dart';
import 'notifications_controller.dart';

//==============================================================================
// SPOCART — Quotes controller
//==============================================================================

class QuotesController extends ChangeNotifier {
  QuotesController(this._repository, this._notifications);

  final QuoteRepository _repository;
  final NotificationsController _notifications;

  List<QuoteRequest> _quotes = <QuoteRequest>[];
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  List<QuoteRequest> get quotes => List<QuoteRequest>.unmodifiable(_quotes);
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;
  int get count => _quotes.length;

  Future<void> load({bool force = false}) async {
    if (_loading || (_loaded && !force)) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _quotes = List<QuoteRequest>.of(await _repository.fetchAll());
      _loaded = true;
    } on AppException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Could not load your quotations.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  QuoteRequest? byId(String id) {
    for (final QuoteRequest q in _quotes) {
      if (q.id == id) return q;
    }
    return null;
  }

  Future<QuoteRequest> submit({
    required QuoteKind kind,
    required List<QuoteItem> items,
    required String notes,
    String? designFilePath,
    String? designFileName,
  }) async {
    if (items.isEmpty) throw const AppException('Add at least one item.');
    final QuoteRequest saved = await _repository.submit(QuoteDraft(
      kind: kind,
      items: items,
      notes: notes,
      designFilePath: designFilePath,
      designFileName: designFileName,
    ));
    _quotes.insert(0, saved);
    _loaded = true;
    notifyListeners();

    if (_notifications.localEvents) {
      await _notifications.pushLocal(
        type: NotificationType.quote,
        title: 'Quotation Request Received',
        body: '${kind.label} ${saved.id} is with our team. We usually respond within one business day.',
        quoteId: saved.id,
      );
    } else {
      _notifications.load(force: true);
    }
    return saved;
  }

  /// Accepts a priced quotation and returns the paymentPending order with its
  /// Razorpay session. The quote is marked accepted locally so the list shows
  /// it without waiting for a refetch.
  ///
  /// Like order placement this is not idempotent — the server creates an order
  /// on every call — so callers must guard against a second tap.
  Future<PlaceOrderResult> accept(String quoteId,
      {required String addressId}) async {
    final PlaceOrderResult result =
        await _repository.accept(quoteId, addressId: addressId);
    final int i = _quotes.indexWhere((q) => q.id == quoteId);
    if (i != -1) {
      _quotes[i] = _quotes[i].copyWith(status: QuoteStatus.accepted);
      notifyListeners();
    }
    return result;
  }

  void reset() {
    _quotes = <QuoteRequest>[];
    _loaded = false;
    notifyListeners();
  }
}
