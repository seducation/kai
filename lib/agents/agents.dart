// Multi-Agent AI System with Execution Transparency
//
// This library provides a complete multi-agent framework with:
// - Step-by-step action logging (truth source)
// - Agent coordination and orchestration
// - Pluggable AI providers (OpenAI, Ollama, etc.)
// - Real-time execution transparency UI
//
// Based on Manus-level architecture principles:
// ❌ No AI "thinking" explanations
// ✅ Real action reporting only

// Core infrastructure
export 'core/core.dart';

// Coordination layer
export 'coordination/coordination.dart';

// Specialized agents
export 'specialized/specialized.dart';

// AI providers
export 'ai/ai.dart';

// Services
export 'services/narrator_service.dart';
export 'services/api_key_manager.dart';

// UI components
export 'ui/ui.dart';
