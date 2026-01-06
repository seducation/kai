import 'agent_capability.dart';
import 'planner_agent.dart';
import 'agent_registry.dart';

/// Helper to set up default agent profiles with capabilities
class AgentProfileSetup {
  /// Register all known agents with their capabilities
  static void registerDefaults(PlannerAgent planner, AgentRegistry registry) {
    // CodeWriterAgent
    if (registry.getAgent('CodeWriter') != null) {
      planner.registerProfile(AgentProfile(
        agentName: 'CodeWriter',
        capabilities: [
          DefaultCapabilities.codeWriter,
          DefaultCapabilities.codeDebugger,
        ],
        maxConcurrentTasks: 3,
      ));
    }

    // WebCrawlerAgent
    if (registry.getAgent('WebCrawler') != null) {
      planner.registerProfile(AgentProfile(
        agentName: 'WebCrawler',
        capabilities: [DefaultCapabilities.webCrawler],
        maxConcurrentTasks: 10,
      ));
    }

    // FileSystemAgent
    if (registry.getAgent('FileSystem') != null) {
      planner.registerProfile(AgentProfile(
        agentName: 'FileSystem',
        capabilities: [DefaultCapabilities.fileManager],
        maxConcurrentTasks: 5,
      ));
    }

    // StorageAgent
    if (registry.getAgent('Storage') != null) {
      planner.registerProfile(AgentProfile(
        agentName: 'Storage',
        capabilities: [DefaultCapabilities.storage],
        maxConcurrentTasks: 10,
      ));
    }

    // DiffAgent
    if (registry.getAgent('Diff') != null) {
      planner.registerProfile(AgentProfile(
        agentName: 'Diff',
        capabilities: [DefaultCapabilities.diff],
        maxConcurrentTasks: 5,
      ));
    }

    // SystemAgent
    if (registry.getAgent('System') != null) {
      planner.registerProfile(AgentProfile(
        agentName: 'System',
        capabilities: [DefaultCapabilities.system],
        maxConcurrentTasks: 3,
      ));
    }

    // AppwriteFunctionAgent
    if (registry.getAgent('AppwriteFunction') != null) {
      planner.registerProfile(AgentProfile(
        agentName: 'AppwriteFunction',
        capabilities: [DefaultCapabilities.appwriteFunction],
        maxConcurrentTasks: 5,
      ));
    }

    // EffectorAgent
    if (registry.getAgent('Effector') != null) {
      planner.registerProfile(AgentProfile(
        agentName: 'Effector',
        capabilities: [
          const AgentCapability(
            id: 'cap_actuation',
            name: 'Actuation',
            category: CapabilityCategory.custom,
            proficiency: 0.9,
            keywords: [
              'actuate',
              'move',
              'execute',
              'cloud',
              'appwrite',
              'shell'
            ],
          ),
        ],
        maxConcurrentTasks: 2,
      ));
    }

    // Logic Organ
    if (registry.getAgent('LogicOrgan') != null) {
      planner.registerProfile(AgentProfile(
        agentName: 'LogicOrgan',
        capabilities: [
          const AgentCapability(
            id: 'cap_logic_cycle',
            name: 'Self-Healing Logic',
            category: CapabilityCategory.code,
            proficiency: 0.95,
            keywords: [
              'logic',
              'organ',
              'self-healing',
              'write and debug',
              'cycle'
            ],
          ),
        ],
        maxConcurrentTasks: 1,
      ));
    }

    // Memory Organ
    if (registry.getAgent('MemoryOrgan') != null) {
      planner.registerProfile(AgentProfile(
        agentName: 'MemoryOrgan',
        capabilities: [
          const AgentCapability(
            id: 'cap_deep_memory',
            name: 'Deep Persistence',
            category: CapabilityCategory.storage,
            proficiency: 0.95,
            keywords: ['memory', 'organ', 'vault', 'long-term', 'persist'],
          ),
        ],
        maxConcurrentTasks: 5,
      ));
    }

    // Discovery Organ
    if (registry.getAgent('DiscoveryOrgan') != null) {
      planner.registerProfile(AgentProfile(
        agentName: 'DiscoveryOrgan',
        capabilities: [
          const AgentCapability(
            id: 'cap_discovery',
            name: 'Data Discovery',
            category: CapabilityCategory.web,
            proficiency: 0.9,
            keywords: ['discovery', 'organ', 'ingest', 'search', 'crawl'],
          ),
        ],
        maxConcurrentTasks: 3,
      ));
    }

    // Digestive System
    if (registry.getAgent('DigestiveSystem') != null) {
      planner.registerProfile(AgentProfile(
        agentName: 'DigestiveSystem',
        capabilities: [
          const AgentCapability(
            id: 'cap_end_to_end_digestion',
            name: 'Knowledge Digestion',
            category: CapabilityCategory.custom,
            proficiency: 1.0,
            keywords: [
              'digestive',
              'system',
              'end-to-end',
              'ingestion to storage',
              'homeostasis'
            ],
          ),
        ],
        maxConcurrentTasks: 1,
      ));
    }

    // Reflex Audit Agent (New in Phase 9)
    if (registry.getAgent('ReflexAudit') != null) {
      planner.registerProfile(AgentProfile(
        agentName: 'ReflexAudit',
        capabilities: [
          const AgentCapability(
            id: 'cap_safety_audit',
            name: 'Safety Audit',
            category: CapabilityCategory.custom,
            proficiency: 1.0,
            keywords: ['safety', 'audit', 'reflex', 'quarantine', 'judge'],
          ),
        ],
        maxConcurrentTasks: 5, // High availability for safety
      ));
    }
  }

  /// Create a custom agent profile
  static AgentProfile createCustomProfile({
    required String agentName,
    required List<AgentCapability> capabilities,
    int maxConcurrentTasks = 5,
  }) {
    return AgentProfile(
      agentName: agentName,
      capabilities: capabilities,
      maxConcurrentTasks: maxConcurrentTasks,
    );
  }
}
