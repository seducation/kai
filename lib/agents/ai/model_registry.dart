import 'ai_provider.dart';

/// Registry for managing multiple AI providers.
/// Allows dynamic switching between providers and models.
class ModelRegistry {
  /// Registered providers
  final Map<String, AIProvider> _providers = {};

  /// Default provider name
  String? _defaultProvider;

  /// Register a provider
  void register(AIProvider provider) {
    _providers[provider.name] = provider;
    _defaultProvider ??= provider.name;
  }

  /// Unregister a provider
  void unregister(String name) {
    _providers.remove(name);
    if (_defaultProvider == name) {
      _defaultProvider = _providers.keys.firstOrNull;
    }
  }

  /// Get a provider by name
  AIProvider? getProvider(String name) => _providers[name];

  /// Get the default provider
  AIProvider get defaultProvider {
    if (_defaultProvider == null || !_providers.containsKey(_defaultProvider)) {
      throw AIProviderException('No AI providers registered');
    }
    return _providers[_defaultProvider]!;
  }

  /// Set the default provider
  void setDefault(String name) {
    if (!_providers.containsKey(name)) {
      throw AIProviderException('Provider "$name" not registered');
    }
    _defaultProvider = name;
  }

  /// Get all registered provider names
  List<String> get providerNames => _providers.keys.toList();

  /// Get all ready providers
  List<AIProvider> get readyProviders =>
      _providers.values.where((p) => p.isReady).toList();

  /// Check if any provider is ready
  bool get hasReadyProvider => readyProviders.isNotEmpty;

  /// Initialize all providers
  Future<void> initializeAll() async {
    for (final provider in _providers.values) {
      try {
        await provider.initialize();
      } catch (_) {
        // Continue with other providers
      }
    }
  }

  /// Get all available models across all providers
  Future<Map<String, List<String>>> getAllModels() async {
    final result = <String, List<String>>{};

    for (final entry in _providers.entries) {
      try {
        final models = await entry.value.getAvailableModels();
        result[entry.key] = models;
      } catch (_) {
        result[entry.key] = [];
      }
    }

    return result;
  }

  /// Complete using default provider
  Future<String> complete(String prompt, {Map<String, dynamic>? options}) {
    return defaultProvider.complete(prompt, options: options);
  }

  /// Chat using default provider
  Future<String> chat(List<ChatMessage> messages,
      {Map<String, dynamic>? options}) {
    return defaultProvider.chat(messages, options: options);
  }

  /// Complete with specific provider
  Future<String> completeWith(
    String providerName,
    String prompt, {
    Map<String, dynamic>? options,
  }) {
    final provider = getProvider(providerName);
    if (provider == null) {
      throw AIProviderException('Provider "$providerName" not found');
    }
    return provider.complete(prompt, options: options);
  }

  /// Dispose all providers
  void dispose() {
    for (final provider in _providers.values) {
      provider.dispose();
    }
    _providers.clear();
  }
}

/// Global model registry instance
final modelRegistry = ModelRegistry();
