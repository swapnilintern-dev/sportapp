import 'package:flutter/foundation.dart';

import '../data/local/local_store.dart';

//==============================================================================
// SPOCART — Settings controller
//------------------------------------------------------------------------------
// Notification preferences and language. Persisted locally.
//==============================================================================

/// Languages the app ships with. Add a value here once its ARB translations
/// exist; the Settings picker lists every value automatically.
enum AppLanguage { english }

extension AppLanguageLabel on AppLanguage {
  String get label => switch (this) {
        AppLanguage.english => 'English',
      };

  static AppLanguage fromName(String? name) => AppLanguage.values.firstWhere(
        (l) => l.name == name,
        orElse: () => AppLanguage.english,
      );
}

class AppSettings {
  const AppSettings({
    this.orderUpdates = true,
    this.offers = true,
    this.priceDrops = true,
    this.newProducts = false,
    this.language = AppLanguage.english,
  });

  final bool orderUpdates;
  final bool offers;
  final bool priceDrops;
  final bool newProducts;
  final AppLanguage language;

  AppSettings copyWith({
    bool? orderUpdates,
    bool? offers,
    bool? priceDrops,
    bool? newProducts,
    AppLanguage? language,
  }) =>
      AppSettings(
        orderUpdates: orderUpdates ?? this.orderUpdates,
        offers: offers ?? this.offers,
        priceDrops: priceDrops ?? this.priceDrops,
        newProducts: newProducts ?? this.newProducts,
        language: language ?? this.language,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'orderUpdates': orderUpdates,
        'offers': offers,
        'priceDrops': priceDrops,
        'newProducts': newProducts,
        'language': language.name,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        orderUpdates: json['orderUpdates'] as bool? ?? true,
        offers: json['offers'] as bool? ?? true,
        priceDrops: json['priceDrops'] as bool? ?? true,
        newProducts: json['newProducts'] as bool? ?? false,
        language: AppLanguageLabel.fromName(json['language'] as String?),
      );
}

class SettingsController extends ChangeNotifier {
  SettingsController(this._store);

  final LocalStore _store;

  AppSettings _settings = const AppSettings();
  bool _loaded = false;

  AppSettings get settings => _settings;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final Map<String, dynamic>? json =
          await _store.readMap(StoreKeys.settings);
      if (json != null) _settings = AppSettings.fromJson(json);
    } catch (_) {
      _settings = const AppSettings();
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> update(AppSettings next) async {
    _settings = next;
    notifyListeners();
    await _store.writeJson(StoreKeys.settings, next.toJson());
  }
}
