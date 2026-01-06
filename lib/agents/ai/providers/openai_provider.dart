import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../ai_provider.dart';

/// OpenAI provider implementation.
/// Supports GPT-4, GPT-3.5-turbo, and other OpenAI models.
class OpenAIProvider implements AIProvider {
  @override
  final String name = 'openai';

  @override
  String get model => _model;
  String _model;

  @override
  bool get isReady => _apiKey != null && _apiKey.isNotEmpty;

  final String? _apiKey;
  final String _baseUrl;
  final Duration _timeout;
  final int _maxTokens;
  final double _temperature;
  final http.Client _client;

  OpenAIProvider({
    required String? apiKey,
    String? baseUrl,
    String model = 'gpt-4',
    Duration timeout = const Duration(seconds: 60),
    int maxTokens = 4096,
    double temperature = 0.7,
    http.Client? client,
  })  : _apiKey = apiKey,
        _baseUrl = baseUrl ?? 'https://api.openai.com/v1',
        _model = model,
        _timeout = timeout,
        _maxTokens = maxTokens,
        _temperature = temperature,
        _client = client ?? http.Client();

  @override
  Future<void> initialize() async {
    if (!isReady) {
      throw AIProviderException('OpenAI API key not configured');
    }
  }

  @override
  Future<String> complete(String prompt,
      {Map<String, dynamic>? options}) async {
    final messages = [ChatMessage.user(prompt)];
    return await chat(messages, options: options);
  }

  @override
  Future<String> chat(List<ChatMessage> messages,
      {Map<String, dynamic>? options}) async {
    if (!isReady) {
      throw AIProviderException('OpenAI provider not ready');
    }

    final body = jsonEncode({
      'model': options?['model'] ?? _model,
      'messages': messages.map((m) => m.toJson()).toList(),
      'max_tokens': options?['max_tokens'] ?? _maxTokens,
      'temperature': options?['temperature'] ?? _temperature,
    });

    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: body,
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw AIProviderException(
          'OpenAI API error: ${response.body}',
          code: response.statusCode.toString(),
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List;
      if (choices.isEmpty) {
        throw AIProviderException('No response from OpenAI');
      }

      return choices[0]['message']['content'] as String;
    } on TimeoutException {
      throw AIProviderException('OpenAI request timed out');
    } catch (e) {
      if (e is AIProviderException) rethrow;
      throw AIProviderException('OpenAI request failed', originalError: e);
    }
  }

  @override
  Stream<String> completeStream(String prompt,
      {Map<String, dynamic>? options}) async* {
    if (!isReady) {
      throw AIProviderException('OpenAI provider not ready');
    }

    final body = jsonEncode({
      'model': options?['model'] ?? _model,
      'messages': [ChatMessage.user(prompt).toJson()],
      'max_tokens': options?['max_tokens'] ?? _maxTokens,
      'temperature': options?['temperature'] ?? _temperature,
      'stream': true,
    });

    final request =
        http.Request('POST', Uri.parse('$_baseUrl/chat/completions'));
    request.headers['Content-Type'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $_apiKey';
    request.body = body;

    final response = await _client.send(request);

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      // Parse SSE format
      for (final line in chunk.split('\n')) {
        if (line.startsWith('data: ') && line != 'data: [DONE]') {
          try {
            final data = jsonDecode(line.substring(6)) as Map<String, dynamic>;
            final delta = data['choices'][0]['delta']['content'];
            if (delta != null) {
              yield delta as String;
            }
          } catch (_) {}
        }
      }
    }
  }

  @override
  Future<List<String>> getAvailableModels() async {
    if (!isReady) return [];

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/models'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      );

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final models = (data['data'] as List)
          .where((m) => (m['id'] as String).contains('gpt'))
          .map((m) => m['id'] as String)
          .toList();

      return models;
    } catch (_) {
      return [];
    }
  }

  /// Set the active model
  void setModel(String model) {
    _model = model;
  }

  @override
  void dispose() {
    _client.close();
  }
}
