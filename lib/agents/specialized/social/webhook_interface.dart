import 'dart:convert';
import 'dart:io';
import 'external_interface.dart';

/// A generic Webhook interface for posting messages to HTTP endpoints.
/// Useful for Slack, Discord, or custom backend integration.
class WebhookInterface extends ExternalInterface {
  final String targetUrl;
  final Map<String, String> headers;

  WebhookInterface({
    required this.targetUrl,
    this.headers = const {'Content-Type': 'application/json'},
  }) : super(name: 'Webhook($targetUrl)');

  @override
  Future<void> connect() async {
    // Webhooks are stateless, but we can verify the URL syntax here
    final uri = Uri.tryParse(targetUrl);
    if (uri == null || !uri.hasScheme) {
      throw ArgumentError('Invalid Webhook URL: $targetUrl');
    }
    isConnected = true;
  }

  @override
  Future<void> send(String message) async {
    if (!isConnected) await connect();

    final client = HttpClient();
    try {
      final uri = Uri.parse(targetUrl);
      final request = await client.postUrl(uri);

      headers.forEach((key, value) {
        request.headers.set(key, value);
      });

      // Simple payload format
      final payload = jsonEncode({
        'text': message,
        'ts': DateTime.now().millisecondsSinceEpoch,
        'sender': 'AI_Agent_System'
      });

      request.write(payload);
      final response = await request.close();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Success
      } else {
        print('[WebhookInterface] Failed to send: ${response.statusCode}');
      }
    } catch (e) {
      print('[WebhookInterface] Connection error: $e');
    } finally {
      client.close();
    }
  }

  @override
  Future<void> disconnect() async {
    isConnected = false;
  }
}
