import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/engagement.dart';
import '../../data/repositories/repositories.dart';
import '../../state/rewards_controller.dart';

//==============================================================================
// SPOCART — Rewards
//------------------------------------------------------------------------------
// Credits, the gift tiers and how far the buyer is from the next one. Every
// number here comes from the server: what a credit is worth, whether credits
// are earned by ordering or by opening the app, and whether today's check-in is
// already claimed. When the business has not switched the programme on, this
// screen says so plainly rather than showing an empty scoreboard.
//==============================================================================

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).rewards.load();
    });
  }

  Future<void> _checkIn() async {
    final RewardsController rewards = AppScope.of(context).rewards;
    try {
      final CheckInResult result = await rewards.checkIn();
      if (!mounted) return;
      showAppSnackBar(
        context,
        result.alreadyCheckedIn
            ? 'You have already checked in today. Come back tomorrow.'
            : '+${result.credited} credits. ${result.streak} day streak!',
        tone: result.alreadyCheckedIn ? SnackTone.neutral : SnackTone.success,
      );
    } on AppException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, tone: SnackTone.error);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not record your check-in.',
            tone: SnackTone.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final RewardsController rewards = AppScope.of(context).rewards;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SpocartAppBar(title: 'Rewards'),
      body: ListenableBuilder(
        listenable: rewards,
        builder: (context, _) {
          if (rewards.loading && !rewards.loaded) return const AppLoader();
          if (rewards.error != null && !rewards.active) {
            return ErrorStateView(
              message: rewards.error,
              onRetry: () => rewards.load(force: true),
            );
          }
          if (!rewards.active) {
            return const EmptyStateView(
              icon: Icons.card_giftcard_outlined,
              title: 'Rewards are on the way',
              message:
                  'SPOCART is putting together credits and gifts for regular '
                  'buyers. We will let you know the moment it starts.',
            );
          }

          final RewardsSummary s = rewards.summary;
          return RefreshIndicator(
            onRefresh: () => rewards.load(force: true),
            child: ContentWidth(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.page),
                children: <Widget>[
                  _BalanceCard(summary: s),
                  if (s.earnsOnCheckIn) ...[
                    const SizedBox(height: AppSpacing.md),
                    _CheckInCard(
                      summary: s,
                      busy: rewards.checkingIn,
                      onCheckIn: _checkIn,
                    ),
                  ],
                  if (s.nextTier != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _NextTierCard(progress: s.nextTier!),
                  ],
                  if (s.tiers.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const Text('Gifts', style: AppTypography.h3),
                    const SizedBox(height: AppSpacing.sm),
                    for (final RewardTier tier in s.tiers) ...[
                      _TierTile(tier: tier),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                  ],
                  if (rewards.ledger.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const Text('Credit history', style: AppTypography.h3),
                    const SizedBox(height: AppSpacing.sm),
                    for (final CreditEntry entry in rewards.ledger)
                      _LedgerRow(entry: entry),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary});

  final RewardsSummary summary;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.black,
      borderColor: AppColors.black,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('SPOCART Credits',
              style: AppTypography.overline.copyWith(color: AppColors.white)),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text('${summary.balance}',
                  style: AppTypography.h1.copyWith(color: AppColors.white)),
              const SizedBox(width: AppSpacing.xs),
              // Only shown once the business has set what a credit is worth.
              if (summary.creditsWorth > 0)
                Text(
                  '≈ ${formatInr(summary.creditsWorth)}',
                  style: AppTypography.small.copyWith(color: AppColors.white),
                ),
            ],
          ),
          if (summary.earnsOnPurchase) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Qualifying purchases: ${formatInr(summary.purchasedTotal)}',
              style: AppTypography.caption.copyWith(color: AppColors.white),
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({
    required this.summary,
    required this.busy,
    required this.onCheckIn,
  });

  final RewardsSummary summary;
  final bool busy;
  final Future<void> Function() onCheckIn;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          const Icon(Icons.local_fire_department_rounded,
              color: AppColors.red, size: 28),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  summary.streak > 0
                      ? '${summary.streak} day streak'
                      : 'Start a streak',
                  style: AppTypography.bodyStrong,
                ),
                Text(
                  summary.checkedInToday
                      ? 'Checked in today — come back tomorrow.'
                      : 'Check in today to earn credits.',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          if (!summary.checkedInToday)
            PrimaryButton(
              label: 'Check In',
              loading: busy,
              expand: false,
              size: ButtonSize.small,
              onPressed: busy ? null : onCheckIn,
            ),
        ],
      ),
    );
  }
}

class _NextTierCard extends StatelessWidget {
  const _NextTierCard({required this.progress});

  final RewardProgress progress;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surface,
      borderColor: AppColors.surface,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Next gift: ${progress.giftLabel}',
              style: AppTypography.bodyStrong),
          const SizedBox(height: 2),
          Text(
            '${formatInr(progress.remaining)} more of purchases to go',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: AppRadius.pillAll,
            child: LinearProgressIndicator(
              value: progress.fraction,
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierTile extends StatelessWidget {
  const _TierTile({required this.tier});

  final RewardTier tier;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          if ((tier.imageUrl ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ProductImage(source: tier.imageUrl, size: 44),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Icon(
                tier.reached
                    ? Icons.card_giftcard_rounded
                    : Icons.lock_outline_rounded,
                color: tier.reached ? AppColors.red : AppColors.textMuted,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(tier.giftLabel, style: AppTypography.bodyStrong),
                Text(
                  tier.reached
                      ? tier.name
                      : '${tier.name} · at ${formatInr(tier.threshold)}',
                  style: AppTypography.caption,
                ),
                if (tier.description.isNotEmpty)
                  Text(tier.description, style: AppTypography.caption),
              ],
            ),
          ),
          if (tier.reached)
            StatusPill(
              label: tier.delivered ? 'Received' : 'Earned',
              color: tier.delivered ? AppColors.success : AppColors.red,
              dense: true,
            ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry});

  final CreditEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(entry.label, style: AppTypography.small),
                Text(
                  formatDate(entry.at),
                  style: AppTypography.caption.copyWith(color: AppColors.textSoft),
                ),
              ],
            ),
          ),
          Text(
            '${entry.isEarn ? '+' : ''}${entry.delta}',
            style: AppTypography.bodyStrong.copyWith(
              color: entry.isEarn ? AppColors.success : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
