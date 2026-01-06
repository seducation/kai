/// Abstract interface for AI providers.
/// Allows plugging in any AI model (OpenAI, Ollama, Claude, Gemini, etc.)
abstract class AIProvider {
  /// Provider name (e.g., "openai", "ollama", "claude")
  String get name;

  /// Model identifier (e.g., "gpt-4", "llama2", "claude-3")
  String get model;

  /// Whether the provider is ready to use
  bool get isReady;

  /// Complete a prompt (simple completion)
  Future<String> complete(String prompt, {Map<String, dynamic>? options});

  /// Chat completion with message history
  Future<String> chat(List<ChatMessage> messages,
      {Map<String, dynamic>? options});

  /// Stream completion (for real-time responses)
  Stream<String> completeStream(String prompt, {Map<String, dynamic>? options});

  /// Get available models from this provider
  Future<List<String>> getAvailableModels();

  /// Initialize the provider (load API keys, etc.)
  Future<void> initialize();

  /// Dispose resources
  void dispose();
}

/// A chat message
class ChatMessage {
  /// Role: "system", "user", "assistant"
  final String role;

  /// Message content
  final String content;

  /// Optional name for multi-user chats
  final String? name;

  /// When the message was sent
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    this.name,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create a system message
  factory ChatMessage.system(String content) =>
      ChatMessage(role: 'system', content: content);

  /// Create a user message
  factory ChatMessage.user(String content) =>
      ChatMessage(role: 'user', content: content);

  /// Create an assistant message
  factory ChatMessage.assistant(String content) =>
      ChatMessage(role: 'assistant', content: content);

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        if (name != null) 'name': name,
      };
}

/// Configuration for AI provider
class AIProviderConfig {
  /// API key (if required)
  final String? apiKey;

  /// Base URL (for self-hosted models)
  final String? baseUrl;

  /// Default model to use
  final String? defaultModel;

  /// Request timeout
  final Duration timeout;

  /// Maximum tokens in response
  final int? maxTokens;

  /// Temperature (0-1)
  final double? temperature;

  const AIProviderConfig({
    this.apiKey,
    this.baseUrl,
    this.defaultModel,
    this.timeout = const Duration(seconds: 60),
    this.maxTokens,
    this.temperature,
  });
}

/// Exception for AI provider errors
class AIProviderException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AIProviderException(this.message, {this.code, this.originalError});

  @override
  String toString() =>
      'AIProviderException: $message${code != null ? ' ($code)' : ''}';
}
