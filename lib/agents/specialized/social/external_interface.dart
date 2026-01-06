/// Abstract base class for external communication channels.
///
/// Implementations allow the SocialAgent to "speak" to the outside world
/// (e.g., Slack, Discord, Appwrite DB, Custom Webhooks).
abstract class ExternalInterface {
  final String name;
  bool isConnected = false;

  ExternalInterface({required this.name});

  /// Initialize the connection (e.g. auth, handshake)
  Future<void> connect();

  /// Send a message to the external world
  Future<void> send(String message);

  /// Disconnect and cleanup
  Future<void> disconnect();
}
