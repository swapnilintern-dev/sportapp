import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_navigator.dart';
import 'app/app_scope.dart';
import 'core/network/api_config.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/feedback.dart';
import 'data/local/local_store.dart';
import 'features/splash/splash_screen.dart';

//==============================================================================
// SPOCART — B2B sports equipment ordering
//------------------------------------------------------------------------------
// Entry point. Opens the local store, builds the service graph and boots into
// the splash screen, which restores the session and routes to Login or Home.
//==============================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(AppTheme.lightOverlay);

  final LocalStore store = await SharedPrefsStore.open();
  final AppServices services = ApiConfig.useDemoBackend
      ? AppServices.demo(store)
      : AppServices.http(store);
  runApp(SpocartApp(services: services));
}

class SpocartApp extends StatefulWidget {
  const SpocartApp({super.key, required this.services});

  final AppServices services;

  @override
  State<SpocartApp> createState() => _SpocartAppState();
}

class _SpocartAppState extends State<SpocartApp> {
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    widget.services.sessionExpired.addListener(_onSessionExpired);
  }

  @override
  void dispose() {
    widget.services.sessionExpired.removeListener(_onSessionExpired);
    widget.services.dispose();
    super.dispose();
  }

  /// The server rejected the token: return to Login with an explanation.
  void _onSessionExpired() {
    final BuildContext? context = _navigator.currentContext;
    if (context == null) return;
    AppNavigator.toLogin(context);
    showAppSnackBar(context, 'Your session has expired. Please sign in again.');
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: widget.services,
      child: MaterialApp(
        navigatorKey: _navigator,
        title: 'SPOCART',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        themeMode: ThemeMode.light,
        // Bound the OS font-size setting so dense B2B rows (steppers, price
        // tables, summaries) reflow instead of overflowing at extreme scales.
        builder: (context, child) {
          final MediaQueryData media = MediaQuery.of(context);
          // Every screen defaults to dark status-bar icons on its light
          // ground; the dark splash overrides this with its own region.
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: AppTheme.lightOverlay,
            child: MediaQuery(
              data: media.copyWith(
                textScaler: media.textScaler.clamp(
                  minScaleFactor: 0.85,
                  maxScaleFactor: 1.3,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        home: const SplashScreen(),
      ),
    );
  }
}
