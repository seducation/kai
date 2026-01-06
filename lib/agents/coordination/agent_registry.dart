import '../core/agent_base.dart';

/// Central registry for managing all agents.
/// Agents must be registered before they can be used by the controller.
class AgentRegistry {
  /// Map of agent name to agent instance
  final Map<String, AgentBase> _agents = {};

  /// Callbacks for agent lifecycle events
  final List<void Function(AgentBase)> _onRegisterCallbacks = [];
  final List<void Function(String)> _onUnregisterCallbacks = [];

  /// Register an agent
  void register(AgentBase agent) {
    if (_agents.containsKey(agent.name)) {
      throw StateError('Agent "${agent.name}" is already registered');
    }
    _agents[agent.name] = agent;

    // Notify listeners
    for (final callback in _onRegisterCallbacks) {
      callback(agent);
    }
  }

  /// Register multiple agents at once
  void registerAll(List<AgentBase> agents) {
    for (final agent in agents) {
      register(agent);
    }
  }

  /// Unregister an agent by name
  void unregister(String name) {
    if (!_agents.containsKey(name)) {
      throw StateError('Agent "$name" is not registered');
    }
    _agents.remove(name);

    // Notify listeners
    for (final callback in _onUnregisterCallbacks) {
      callback(name);
    }
  }

  /// Get an agent by name
  AgentBase? getAgent(String name) => _agents[name];

  /// Get an agent by name, throw if not found
  AgentBase requireAgent(String name) {
    final agent = _agents[name];
    if (agent == null) {
      throw StateError('Agent "$name" is not registered');
    }
    return agent;
  }

  /// Get an agent of a specific type
  T? getAgentOfType<T extends AgentBase>() {
    for (final agent in _agents.values) {
      if (agent is T) return agent;
    }
    return null;
  }

  /// Get all agents
  List<AgentBase> get allAgents => _agents.values.toList();

  /// Get all agent names
  List<String> get agentNames => _agents.keys.toList();

  /// Check if an agent is registered
  bool hasAgent(String name) => _agents.containsKey(name);

  /// Get count of registered agents
  int get count => _agents.length;

  /// Add callback for when agent is registered
  void onRegister(void Function(AgentBase) callback) {
    _onRegisterCallbacks.add(callback);
  }

  /// Add callback for when agent is unregistered
  void onUnregister(void Function(String) callback) {
    _onUnregisterCallbacks.add(callback);
  }

  /// Clear all agents
  void clear() {
    _agents.clear();
  }
}

/// Global agent registry instance
final agentRegistry = AgentRegistry();
