import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  AppSettings(this._prefs);

  final SharedPreferences _prefs;

  static const keyMetadataOptIn = 'metadata_lookup_opt_in';

  bool get metadataLookupEnabled =>
      _prefs.getBool(keyMetadataOptIn) ?? false;

  Future<void> setMetadataLookupEnabled(bool value) =>
      _prefs.setBool(keyMetadataOptIn, value);
}
