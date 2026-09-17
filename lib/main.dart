import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_scope.dart';
import 'core/theme/app_theme.dart';
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
  runApp(SpocartApp(services: AppServices.demo(store)));
}

class SpocartApp extends StatefulWidget {
  const SpocartApp({super.key, required this.services});

  final AppServices services;

  @override
  State<SpocartApp> createState() => _SpocartAppState();
}

class _SpocartAppState extends State<SpocartApp> {
  @override
  void dispose() {
    widget.services.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: widget.services,
      child: MaterialApp(
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
