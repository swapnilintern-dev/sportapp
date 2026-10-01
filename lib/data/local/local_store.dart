import 'dart:convert';

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
