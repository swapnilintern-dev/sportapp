import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

//==============================================================================
// SPOCART — API configuration
//------------------------------------------------------------------------------
// Single source of truth for the backend base URL.
//
//   flutter run --dart-define=API_BASE_URL=https://api.spocart.in/api/v1
//   flutter run --dart-define=USE_DEMO_BACKEND=true   (no server needed)
//
// Without a define the app targets a local `spocart-api` on port 3000:
// iOS simulator / desktop → 127.0.0.1, Android emulator → 10.0.2.2.
// A physical phone needs the Mac's LAN IP via --dart-define.
//==============================================================================
abstract final class ApiConfig {
  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// True when the app should run on the on-device demo repositories.
  static const bool useDemoBackend =
      bool.fromEnvironment('USE_DEMO_BACKEND', defaultValue: false);

  static String get baseUrl {
    if (_override.isNotEmpty) return _stripSlash(_override);
    final String host =
        !kIsWeb && Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
    return 'http://$host:3000/api/v1';
  }

  static const Duration timeout = Duration(seconds: 20);

  static String _stripSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
