import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

//==============================================================================
// SPOCART — Local key/value store
//------------------------------------------------------------------------------
// Thin JSON wrapper over SharedPreferences. Session, cart, wishlist, addresses,
// orders, quotes and notifications persist here so the app resumes exactly
// where the buyer left off. Every read is defensive: corrupt or missing data
// resolves to null rather than throwing.
//==============================================================================

abstract class LocalStore {
  Future<Map<String, dynamic>?> readMap(String key);
  Future<List<Map<String, dynamic>>?> readList(String key);
  Future<List<String>?> readStrings(String key);
  Future<void> writeJson(String key, Object? value);
  Future<void> writeStrings(String key, List<String> value);
  Future<void> remove(String key);
}

class SharedPrefsStore implements LocalStore {
  SharedPrefsStore._(this._prefs);

  final SharedPreferences _prefs;

  static Future<SharedPrefsStore> open() async =>
      SharedPrefsStore._(await SharedPreferences.getInstance());

  @override
  Future<Map<String, dynamic>?> readMap(String key) async {
    final Object? decoded = _decode(key);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>?> readList(String key) async {
    final Object? decoded = _decode(key);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return null;
  }

  @override
  Future<List<String>?> readStrings(String key) async =>
      _prefs.getStringList(key);

  @override
  Future<void> writeJson(String key, Object? value) async {
    if (value == null) {
      await _prefs.remove(key);
      return;
    }
    await _prefs.setString(key, jsonEncode(value));
  }

  @override
  Future<void> writeStrings(String key, List<String> value) async {
    await _prefs.setStringList(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  Object? _decode(String key) {
    final String? raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
}

/// In-memory store for tests and the widget-test harness.
class MemoryStore implements LocalStore {
  final Map<String, Object?> _data = <String, Object?>{};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async {
    final Object? v = _data[key];
    return v is Map ? Map<String, dynamic>.from(v) : null;
  }

  @override
  Future<List<Map<String, dynamic>>?> readList(String key) async {
    final Object? v = _data[key];
    if (v is List) {
      return v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    }
    return null;
  }

  @override
  Future<List<String>?> readStrings(String key) async {
    final Object? v = _data[key];
    return v is List ? v.cast<String>() : null;
  }

  @override
  Future<void> writeJson(String key, Object? value) async {
    if (value == null) {
      _data.remove(key);
    } else {
      // Round-trip through JSON so the behaviour matches SharedPrefsStore.
      _data[key] = jsonDecode(jsonEncode(value));
    }
  }

  @override
  Future<void> writeStrings(String key, List<String> value) async {
    _data[key] = List<String>.of(value);
  }

  @override
  Future<void> remove(String key) async {
    _data.remove(key);
  }
}

//==============================================================================
// Secrets
//------------------------------------------------------------------------------
// The auth token is the one value here worth protecting: it is a 30-day bearer
// credential, and SharedPreferences is plain XML on Android. It lives in the
// platform keystore instead, behind the same shape as LocalStore so tests can
// swap in memory. Everything else the app caches is not a secret.
//==============================================================================

abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class KeychainSecretStore implements SecretStore {
  const KeychainSecretStore();

  // Defaults are what we want on both platforms: AES-GCM with RSA key wrapping
  // in the Android keystore, the iOS keychain, no biometric prompt, and
  // resetOnError so a damaged store clears itself instead of throwing.
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // A device that cannot open the keystore — a damaged keychain, a restored
  // backup — signs the buyer out rather than crashing the app on launch.
  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // Deliberately no fallback: writing the token to plain storage would
      // undo the only reason this class exists.
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {
      // Already gone, or unreadable — either way there is nothing to clear.
    }
  }
}

/// In-memory secrets for tests and the widget-test harness.
class MemorySecretStore implements SecretStore {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

abstract final class StoreKeys {
  static const String session = 'session';
  static const String cart = 'cart';
  static const String wishlist = 'wishlist';
  static const String addresses = 'addresses';
  static const String orders = 'orders';
  static const String quotes = 'quotes';
  static const String notifications = 'notifications';
  static const String settings = 'settings';
  static const String team = 'team';

  /// Keys the demo backend stores per account (see AccountKey.scoped). The
  /// session itself is global and is rewritten, so it is not in this list.
  static const List<String> scoped = <String>[
    cart,
    wishlist,
    addresses,
    orders,
    quotes,
    notifications,
    settings,
    team,
  ];
}
