import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../ai_provider.dart';

/// Ollama provider for local AI models.
/// Supports Llama, Mistral, CodeLlama, and other local models.
class OllamaProvider implements AIProvider {
  @override
  final String name = 'ollama';

  @override
  String get model => _model;
  String _model;

  @override
  bool get isReady => _isConnected;
  bool _isConnected = false;

  final String _baseUrl;
  final Duration _timeout;
  final http.Client _client;

  OllamaProvider({
    String? baseUrl,
    String model = 'llama2',
    Duration timeout = const Duration(seconds: 120),
    http.Client? client,
  })  : _baseUrl = baseUrl ?? 'http://localhost:11434',
        _model = model,
        _timeout = timeout,
        _client = client ?? http.Client();

  @override
  Future<void> initialize() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/tags'))
          .timeout(const Duration(seconds: 5));

      _isConnected = response.statusCode == 200;
    } catch (_) {
      _isConnected = false;
    }
  }

  @override
  Future<String> complete(String prompt,
      {Map<String, dynamic>? options}) async {
    if (!isReady) {
      throw AIProviderException('Ollama not connected. Is it running?');
    }

    final body = jsonEncode({
      'model': options?['model'] ?? _model,
      'prompt': prompt,
      'stream': false,
    });

    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/api/generate'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw AIProviderException(
          'Ollama error: ${response.body}',
          code: response.statusCode.toString(),
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['response'] as String;
    } on TimeoutException {
      throw AIProviderException('Ollama request timed out');
    } catch (e) {
      if (e is AIProviderException) rethrow;
      throw AIProviderException('Ollama request failed', originalError: e);
    }
  }

  @override
  Future<String> chat(List<ChatMessage> messages,
      {Map<String, dynamic>? options}) async {
    if (!isReady) {
      throw AIProviderException('Ollama not connected');
    }

    final body = jsonEncode({
      'model': options?['model'] ?? _model,
      'messages': messages.map((m) => m.toJson()).toList(),
      'stream': false,
    });

    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/api/chat'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw AIProviderException('Ollama chat error: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['message']['content'] as String;
    } on TimeoutException {
      throw AIProviderException('Ollama chat timed out');
    } catch (e) {
      if (e is AIProviderException) rethrow;
      throw AIProviderException('Ollama chat failed', originalError: e);
    }
  }

  @override
  Stream<String> completeStream(String prompt,
      {Map<String, dynamic>? options}) async* {
    if (!isReady) {
      throw AIProviderException('Ollama not connected');
    }

    final body = jsonEncode({
      'model': options?['model'] ?? _model,
      'prompt': prompt,
      'stream': true,
    });

    final request = http.Request('POST', Uri.parse('$_baseUrl/api/generate'));
    request.headers['Content-Type'] = 'application/json';
    request.body = body;

    final response = await _client.send(request);

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      for (final line in chunk.split('\n')) {
        if (line.isNotEmpty) {
          try {
            final data = jsonDecode(line) as Map<String, dynamic>;
            if (data.containsKey('response')) {
              yield data['response'] as String;
            }
          } catch (_) {}
        }
      }
    }
  }

  @override
  Future<List<String>> getAvailableModels() async {
    try {
      final response = await _client.get(Uri.parse('$_baseUrl/api/tags'));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final models =
          (data['models'] as List).map((m) => m['name'] as String).toList();

      return models;
    } catch (_) {
      return [];
    }
  }

  /// Pull a model from Ollama registry
  Future<void> pullModel(String modelName) async {
    final body = jsonEncode({'name': modelName});

    await _client.post(
      Uri.parse('$_baseUrl/api/pull'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
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
