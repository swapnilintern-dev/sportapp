import 'package:flutter/foundation.dart';

import '../data/models/engagement.dart';
import '../data/repositories/repositories.dart';

//==============================================================================
// SPOCART — Rewards controller
//------------------------------------------------------------------------------
// Holds the Rewards screen's state. The server decides everything that matters:
// whether the programme runs at all, what a credit is worth, and whether
// today's check-in has been claimed. Nothing here guesses a rate or a balance,
// so the screen can never promise something the business has not set.
//==============================================================================

class RewardsController extends ChangeNotifier {
  RewardsController(this._repository);

  final RewardRepository _repository;

  RewardsSummary _summary = RewardsSummary.off;
  List<CreditEntry> _ledger = const <CreditEntry>[];
  bool _loading = false;
  bool _checkingIn = false;
  bool _loaded = false;
  String? _error;

  RewardsSummary get summary => _summary;
  List<CreditEntry> get ledger => _ledger;
  bool get loading => _loading;
  bool get checkingIn => _checkingIn;
  bool get loaded => _loaded;
  String? get error => _error;

  /// True only when the business has switched the programme on. Every entry
  /// point in the app hides itself when this is false.
  bool get active => _summary.active;

  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (_loaded && !force) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _summary = await _repository.fetchRewards();
      _ledger = _summary.active
          ? await _repository.fetchLedger()
          : const <CreditEntry>[];
      _loaded = true;
    } on AppException catch (e) {
      _error = e.message;
      _summary = RewardsSummary.off;
    } catch (_) {
      _error = 'Could not load your rewards. Please try again.';
      _summary = RewardsSummary.off;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Claims today's check-in and refreshes. Returns what the server did, so the
  /// screen can say "already claimed" rather than pretending it credited again.
  Future<CheckInResult> checkIn() async {
    if (_checkingIn) {
      throw const AppException('Just a moment — your check-in is being recorded.');
    }
    _checkingIn = true;
    notifyListeners();
    try {
      final CheckInResult result = await _repository.checkIn();
      await load(force: true);
      return result;
    } finally {
      _checkingIn = false;
      notifyListeners();
    }
  }

  void reset() {
    _summary = RewardsSummary.off;
    _ledger = const <CreditEntry>[];
    _loaded = false;
    _error = null;
    notifyListeners();
  }
}
