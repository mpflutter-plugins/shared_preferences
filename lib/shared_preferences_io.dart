import 'shared_preferences_platform_interface.dart';

/// Stores data in memory.
///
/// Data does not persist across application restarts. This is useful in unit-tests.
class SharedPreferencesStore extends SharedPreferencesStorePlatform {
  final Map<String, Object> _data = {};

  @override
  Future<bool> clear() async {
    _data.clear();
    return true;
  }

  @override
  Future<Map<String, Object>> getAll() async {
    return Map<String, Object>.from(_data);
  }

  @override
  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    _data[key] = value;
    return true;
  }
}
