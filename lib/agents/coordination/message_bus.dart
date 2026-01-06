import 'dart:async';

/// Message types for agent-to-agent communication
enum MessageType {
  /// Request work from another agent
  request,

  /// Response to a request
  response,

  /// Broadcast to all agents
  broadcast,

  /// Error notification
  error,

  /// Status update
  status,

  /// Cancel a running task
  cancel,
}

/// A message sent between agents
class AgentMessage {
  /// Unique message ID
  final String id;

  /// Type of message
  final MessageType type;

  /// Sender agent name
  final String from;

  /// Target agent name (null for broadcasts)
  final String? to;

  /// Message payload
  final dynamic payload;

  /// When the message was sent
  final DateTime timestamp;

  /// Optional correlation ID for request/response matching
  final String? correlationId;

  AgentMessage({
    required this.id,
    required this.type,
    required this.from,
    this.to,
    this.payload,
    this.correlationId,
  }) : timestamp = DateTime.now();

  /// Create a response to this message
  AgentMessage respond({
    required String from,
    required dynamic payload,
  }) {
    return AgentMessage(
      id: '${id}_response',
      type: MessageType.response,
      from: from,
      to: this.from,
      payload: payload,
      correlationId: id,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'from': from,
      'to': to,
      'payload': payload,
      'timestamp': timestamp.toIso8601String(),
      'correlation_id': correlationId,
    };
  }
}

/// Central message bus for agent-to-agent communication.
/// Agents can subscribe to messages and broadcast events.
class MessageBus {
  /// Stream controller for all messages
  final StreamController<AgentMessage> _messageController =
      StreamController<AgentMessage>.broadcast();

  /// Per-agent subscriptions
  final Map<String, StreamController<AgentMessage>> _agentControllers = {};

  /// Message history (limited)
  final List<AgentMessage> _history = [];
  static const int _maxHistory = 100;

  /// Counter for message IDs
  int _messageCounter = 0;

  /// Broadcast a message to all agents
  void broadcast(AgentMessage message) {
    _addToHistory(message);
    _messageController.add(message);

    // Also send to specific agent if targeted
    if (message.to != null) {
      _agentControllers[message.to]?.add(message);
    }
  }

  /// Send a message to a specific agent
  void send({
    required String from,
    required String to,
    required dynamic payload,
    MessageType type = MessageType.request,
  }) {
    final message = AgentMessage(
      id: 'msg_${++_messageCounter}',
      type: type,
      from: from,
      to: to,
      payload: payload,
    );

    _addToHistory(message);

    // Send to specific agent
    _agentControllers[to]?.add(message);

    // Also add to general stream
    _messageController.add(message);
  }

  /// Subscribe to all messages
  Stream<AgentMessage> get allMessages => _messageController.stream;

  /// Subscribe to messages for a specific agent
  Stream<AgentMessage> subscribe(String agentName) {
    _agentControllers.putIfAbsent(
      agentName,
      () => StreamController<AgentMessage>.broadcast(),
    );
    return _agentControllers[agentName]!.stream;
  }

  /// Subscribe to messages of a specific type
  Stream<AgentMessage> subscribeToType(MessageType type) {
    return _messageController.stream.where((m) => m.type == type);
  }

  /// Get recent message history
  List<AgentMessage> get history => List.unmodifiable(_history);

  /// Get messages from a specific agent
  List<AgentMessage> getMessagesFrom(String agentName) {
    return _history.where((m) => m.from == agentName).toList();
  }

  /// Get messages to a specific agent
  List<AgentMessage> getMessagesTo(String agentName) {
    return _history.where((m) => m.to == agentName).toList();
  }

  void _addToHistory(AgentMessage message) {
    _history.add(message);
    if (_history.length > _maxHistory) {
      _history.removeAt(0);
    }
  }

  /// Clear history
  void clearHistory() {
    _history.clear();
  }

  /// Dispose all resources
  void dispose() {
    _messageController.close();
    for (final controller in _agentControllers.values) {
      controller.close();
    }
    _agentControllers.clear();
  }
}

/// Global message bus instance
final messageBus = MessageBus();
