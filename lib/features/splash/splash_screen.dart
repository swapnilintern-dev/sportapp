import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_navigator.dart';
import '../../app/app_scope.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/media.dart';

//==============================================================================
// SPOCART — Splash
//------------------------------------------------------------------------------
// Full-bleed stadium photo under a dark gradient, the wordmark on a white
// card, and a thin progress bar. Restores the session while the intro plays,
// then routes to Home (signed in) or Login.
//==============================================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _minimumDisplay = Duration(milliseconds: 2200);

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: _minimumDisplay,
  );

  late final Animation<double> _cardFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.05, 0.45, curve: Curves.easeOut),
  );

  late final Animation<Offset> _cardRise = Tween<Offset>(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.05, 0.5, curve: Curves.easeOutCubic),
  ));

  late final Animation<double> _footerFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _intro.forward();
    _boot();
  }

  Future<void> _boot() async {
    final AppServices services = AppScope.of(context);
    // Session restore and the intro run in parallel; whichever is slower wins.
    await Future.wait<void>(<Future<void>>[
      services.bootstrap(),
      Future<void>.delayed(_minimumDisplay),
    ]);
    if (!mounted) return;
    if (services.session.isSignedIn) {
      AppNavigator.toHome(context);
    } else {
      AppNavigator.toLogin(context);
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.darkOverlay,
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/football_match.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppColors.black),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xCC0B0B0C),
                    Color(0x990B0B0C),
                    Color(0xE60B0B0C),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.xl,
                ),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    FadeTransition(
                      opacity: _cardFade,
                      child: SlideTransition(
                        position: _cardRise,
                        child: const _BrandCard(),
                      ),
                    ),
                    const Spacer(flex: 4),
                    FadeTransition(
                      opacity: _footerFade,
                      child: Column(
                        children: [
                          Text(
                            'All Sports  ·  All Brands  ·  One Platform',
                            textAlign: TextAlign.center,
                            style: AppTypography.small.copyWith(
                              color: AppColors.textOnDarkSoft,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SizedBox(
                            width: 120,
                            child: ClipRRect(
                              borderRadius: AppRadius.pillAll,
                              child: AnimatedBuilder(
                                animation: _intro,
                                builder: (_, _) => LinearProgressIndicator(
                                  value: _intro.value,
                                  minHeight: 3,
                                  backgroundColor:
                                      AppColors.white.withValues(alpha: 0.18),
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxl,
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: AppRadius.xlAll,
          boxShadow: AppShadows.raised,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(height: 96),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppInfo.tagline,
              textAlign: TextAlign.center,
              style: AppTypography.title.copyWith(color: AppColors.textSoft),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'B2B  ·  Bulk  ·  Trusted',
              textAlign: TextAlign.center,
              style: AppTypography.overline.copyWith(color: AppColors.red),
            ),
          ],
        ),
      ),
    );
  }
}
