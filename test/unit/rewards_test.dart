import 'package:flutter_test/flutter_test.dart';
import 'package:sport/data/models/engagement.dart';
import 'package:sport/data/repositories/repositories.dart';
import 'package:sport/state/rewards_controller.dart';

//==============================================================================
// Rewards: the app must never promise a rate, a balance or a gift the business
// has not actually set. Everything comes from the server, including whether the
// programme runs at all.
//==============================================================================

class _FakeRewardRepository implements RewardRepository {
  _FakeRewardRepository({
    this.summary = RewardsSummary.off,
    this.entries = const <CreditEntry>[],
    this.checkInResult,
    this.failWith,
  });

  RewardsSummary summary;
  List<CreditEntry> entries;
  CheckInResult? checkInResult;
  AppException? failWith;

  int summaryCalls = 0;
  int ledgerCalls = 0;
  int checkInCalls = 0;

  @override
  Future<RewardsSummary> fetchRewards() async {
    summaryCalls++;
    if (failWith != null) throw failWith!;
    return summary;
  }

  @override
  Future<List<CreditEntry>> fetchLedger({int offset = 0, int limit = 25}) async {
    ledgerCalls++;
    return entries;
  }

  @override
  Future<CheckInResult> checkIn() async {
    checkInCalls++;
    if (failWith != null) throw failWith!;
    return checkInResult ??
        const CheckInResult(
            credited: 10, alreadyCheckedIn: false, balance: 10, streak: 1);
  }
}

RewardsSummary _on({
  int balance = 120,
  double worth = 30,
  int streak = 2,
  bool checkedIn = false,
  bool earnsOnCheckIn = true,
  List<RewardTier> tiers = const <RewardTier>[],
  RewardProgress? next,
}) =>
    RewardsSummary(
      active: true,
      balance: balance,
      creditsWorth: worth,
      purchasedTotal: 240000,
      streak: streak,
      checkedInToday: checkedIn,
      earnsOnCheckIn: earnsOnCheckIn,
      earnsOnPurchase: true,
      nextTier: next,
      tiers: tiers,
    );

void main() {
  group('while the programme is off', () {
    test('nothing is claimed and the ledger is not even fetched', () async {
      final _FakeRewardRepository repo = _FakeRewardRepository();
      final RewardsController c = RewardsController(repo);
      await c.load();

      expect(c.active, isFalse);
      expect(c.summary.balance, 0);
      expect(c.ledger, isEmpty);
      expect(repo.ledgerCalls, 0, reason: 'no balance to explain');
    });

    test('a failure leaves it off rather than half on', () async {
      final RewardsController c = RewardsController(
        _FakeRewardRepository(failWith: const AppException('rewards are down')),
      );
      await c.load();
      expect(c.active, isFalse);
      expect(c.error, 'rewards are down');
    });
  });

  group('once it is on', () {
    test('the server\'s numbers are shown as they are', () async {
      final RewardsController c = RewardsController(_FakeRewardRepository(
        summary: _on(balance: 350, worth: 87.5),
        entries: <CreditEntry>[
          CreditEntry(
            id: '1', delta: 350, reason: 'orderEarned',
            note: 'Earned on order SC-2026-0004', at: DateTime(2026, 10, 1),
          ),
        ],
      ));
      await c.load();

      expect(c.active, isTrue);
      expect(c.summary.balance, 350);
      expect(c.summary.creditsWorth, 87.5);
      expect(c.ledger.single.label, 'Earned on an order');
      expect(c.ledger.single.isEarn, isTrue);
    });

    test('loading twice does not ask twice, but a refresh does', () async {
      final _FakeRewardRepository repo =
          _FakeRewardRepository(summary: _on());
      final RewardsController c = RewardsController(repo);
      await c.load();
      await c.load();
      expect(repo.summaryCalls, 1);

      await c.load(force: true);
      expect(repo.summaryCalls, 2);
    });

    test('a second check-in reports that it was already claimed', () async {
      final _FakeRewardRepository repo = _FakeRewardRepository(
        summary: _on(checkedIn: true),
        checkInResult: const CheckInResult(
            credited: 0, alreadyCheckedIn: true, balance: 10, streak: 1),
      );
      final RewardsController c = RewardsController(repo);
      await c.load();

      final CheckInResult result = await c.checkIn();
      expect(result.credited, 0);
      expect(result.alreadyCheckedIn, isTrue);
    });

    test('a check-in refreshes the screen afterwards', () async {
      final _FakeRewardRepository repo =
          _FakeRewardRepository(summary: _on());
      final RewardsController c = RewardsController(repo);
      await c.load();
      expect(repo.summaryCalls, 1);

      await c.checkIn();
      expect(repo.checkInCalls, 1);
      expect(repo.summaryCalls, 2, reason: 'the balance has moved');
      expect(c.checkingIn, isFalse);
    });

    test('signing out forgets it, so the next buyer starts clean', () async {
      final RewardsController c =
          RewardsController(_FakeRewardRepository(summary: _on(balance: 99)));
      await c.load();
      expect(c.summary.balance, 99);

      c.reset();
      expect(c.active, isFalse);
      expect(c.summary.balance, 0);
      expect(c.loaded, isFalse);
    });
  });

  group('parsing what the server sends', () {
    test('off is off, whatever else is in the payload', () {
      final RewardsSummary s = RewardsSummary.fromJson(<String, dynamic>{
        'active': false,
        'settings': <String, dynamic>{'earnsOnCheckIn': true},
      });
      expect(s.active, isFalse);
      expect(s.balance, 0);
      expect(s.tiers, isEmpty);
    });

    test('a running programme with a gift in progress', () {
      final RewardsSummary s = RewardsSummary.fromJson(<String, dynamic>{
        'active': true,
        'settings': <String, dynamic>{
          'earnsOnCheckIn': true, 'earnsOnPurchase': true,
        },
        'balance': 240,
        'creditsWorth': 60,
        'purchasedTotal': 117528,
        'streak': 3,
        'checkedInToday': true,
        'nextTier': <String, dynamic>{
          'name': 'Gold', 'giftLabel': 'Free kit bag',
          'threshold': 300000, 'remaining': 182472, 'progress': 0.39,
        },
        'tiers': <Map<String, dynamic>>[
          {
            'id': 't1', 'name': 'Silver', 'description': '', 'giftLabel': 'Cap',
            'threshold': 50000, 'reached': true, 'status': 'delivered',
          },
        ],
      });
      expect(s.active, isTrue);
      expect(s.balance, 240);
      expect(s.streak, 3);
      expect(s.checkedInToday, isTrue);
      expect(s.nextTier!.giftLabel, 'Free kit bag');
      expect(s.nextTier!.fraction, closeTo(0.39, 0.001));
      expect(s.tiers.single.delivered, isTrue);
    });

    test('a progress figure outside 0–1 is clamped, never drawn past the end', () {
      final RewardProgress over = RewardProgress.fromJson(
          <String, dynamic>{'progress': 4.2, 'remaining': 0, 'threshold': 1});
      final RewardProgress under = RewardProgress.fromJson(
          <String, dynamic>{'progress': -1, 'remaining': 0, 'threshold': 1});
      expect(over.fraction, 1.0);
      expect(under.fraction, 0.0);
    });

    test('every ledger reason reads as plain words', () {
      for (final String reason in <String>[
        'orderEarned', 'orderReversed', 'dailyCheckIn', 'referral',
        'redeemed', 'adminAdjust', 'expired', 'somethingNew',
      ]) {
        final CreditEntry e = CreditEntry.fromJson(<String, dynamic>{
          'id': 1, 'delta': 5, 'reason': reason, 'note': '',
          'at': '2026-10-01T00:00:00Z',
        });
        expect(e.label, isNotEmpty, reason: reason);
        expect(e.label, isNot(reason), reason: 'should not show the raw code');
      }
    });
  });
}
