import 'package:shared_preferences/shared_preferences.dart';

/// Small storage boundary, replaceable by a database or cloud-backed repository.
abstract interface class ProgressStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class PreferencesProgressStore implements ProgressStore {
  PreferencesProgressStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);
}

/// Deterministic in-memory storage for tests and previews; never used by load().
class MemoryProgressStore implements ProgressStore {
  MemoryProgressStore([Map<String, String>? seed]) : values = {...?seed};
  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
