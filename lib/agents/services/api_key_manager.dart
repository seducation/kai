import 'package:shared_preferences/shared_preferences.dart';

/// Manages secure storage of API keys for various providers.
class ApiKeyManager {
  static const String _prefix = 'agent_api_key_';
  final SharedPreferences _prefs;

  ApiKeyManager(this._prefs);

  /// Initialize the manager instance
  static Future<ApiKeyManager> init() async {
    final prefs = await SharedPreferences.getInstance();
    return ApiKeyManager(prefs);
  }

  /// Save an API key for a specific provider
  Future<void> setKey(String providerId, String key) async {
    if (key.isEmpty) {
      await _prefs.remove('$_prefix$providerId');
    } else {
      await _prefs.setString('$_prefix$providerId', key);
    }
  }

  /// Get the API key for a specific provider
  String? getKey(String providerId) {
    return _prefs.getString('$_prefix$providerId');
  }

  /// Check if a key exists for a provider
  bool hasKey(String providerId) {
    return _prefs.containsKey('$_prefix$providerId');
  }

  /// Remove a key for a provider
  Future<void> removeKey(String providerId) async {
    await _prefs.remove('$_prefix$providerId');
  }
}
