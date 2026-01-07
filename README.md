# AI Agent Orchestration & Knowledge Vault 🧠🚀

A powerful, visual, and persistent multi-agent orchestration system built with Flutter. This project implements a **Manus-style** architecture where every agent action is transparently logged, and execution logic is driven by a visual graph.

## 🌟 Key Features

### 1. Visual Node Orchestrator 🎨
- **Blender/Unreal Style Interface**: A 2D canvas for dragging, dropping, and connecting agents.
- **Dynamic Routing**: The execution path is determined by the connections you draw.
- **Typed Ports**: Compile-time and runtime validation of data types (Text, Image, Code, JSON) between agents.
- **Execution Highlighting**: Nodes glow in real-time as agents work (**Blue** = Running, **Green** = Success, **Red** = Error).

### 2. Persistent Knowledge Vault 🗄️
- **File-Based Memory**: Agent outputs are not just kept in RAM; they are saved permanently as Markdown files in `documents/vault/`.
- **Transparency**: Every step taken by an agent is logged to the "System Memory", ensuring offline reuse and data transparency.
- **Offline Capability**: View and reuse previously generated agent insights even without an internet connection.

### 3. Self-Modifying System Agent 🏗️
- **Agentic Architect**: Includes a specialized `SystemAgent` that can modify the execution graph itself based on natural language instructions.
- **Natural Language Control**: Say *"Connect the WebCrawler to the Translator"* and the graph updates automatically.

### 4. Robust & Resilient Core 🛡️
- **Auto-Healing**: The `ControllerAgent` includes retry logic for failed steps.
- **Execution Management**: Advanced modes: `Normal`, `Dry Run` (simulated), `Replay` (re-run history), and `Undo/Redo`.
- **Failure Vault**: Git-like persistence for failed executions, allowing "Redo" with original inputs.
- **State Persistence**: Survival through restarts; the controller saves its runtime state to the vault.

### 5. Intelligent Brain & Planning 🧠
- **PlannerAgent**: Dynamic task routing using **Deterministic** (rule-based) and **Exploratory** (learning) modes.
- **Reliability Tracker**: Monitors agent performance and success rates to optimize task allocation.
- **Capability System**: Fine-grained proficiency scoring for agents (Code, Web, Search, etc.).

### 6. Storage Permissions & Lineage 🧬
- **Hierarchy System**: Organized storage zones (`temporary`, `permanent/vault`, `cache`, `agent-owned`).
- **Access Gate**: Secure, auditable permission system with hash-chained audit logs.
- **Dataset Lineage**: Full audit trail of which datasets trained which models, including version comparison views.

### 7. Adaptive UI 📱💻
- **Responsive Layout**:
  - **Desktop/Tablet**: Full interactive Graph Editor.
  - **Mobile**: Automatically switches to an **Execution Timeline (Feed View)**.
- **Specialized Dashboards**:
  - **Failure Vault UI**: Manage failures and history.
  - **Audit & Lineage UI**: Inspect training history and dataset provenance.
  - **System Health & Sleep**: Real-time biological monitoring.

### 8. Autonomic Nervous System 🩹
- **Heartbeat Loop**: Runs a background pulse every 30s to monitor system health and storage integrity.
- **Self-Healing**: Automatically detects and repairs minor file system corruption and storage quota issues.
- **Health Indicators**: Visual monitoring of system state (Healthy, Degraded, Critical).

### 9. Sleep Mode & Optimization 😴
- **Idle Optimization**: The "Brain" enters sleep mode after 5 minutes of user inactivity.
- **Sleep Stages**:
  - **Light Sleep**: Cleans temporary cache and deletes discarded intermediate files.
  - **Deep Sleep**: Compacts execution history and re-indexes the failure vault.
  - **REM Sleep (Dreaming)**: Triggers Dreaming Mode for autonomous simulation and optimization.
- **Instant Wake**: All background processes yield immediately when the user interacts or sends a request.

### 10. Priority + Rule Engine (PRE) ⚖️⚡
- **Rule Engine**: The supreme authority for all agent actions. Enforces deterministic safety rules (blocking `rm -rf`, `sudo`, etc.) before any execution.
- **Priority Scheduler**: Intelligent task queue with integer-based priorities (`Reflex`, `Critical`, `Emergency`, `High`, `Normal`, `Low`).
- **Interactive Management**: Dedicated **Rules & Priority Engine UI** to monitor active rules and the prioritized task pipeline.

### 11. Behavioral Intelligence (JARVIS-Level: 95% Certified) 🎭🔮
- **Mission Mode**: Long-running objectives with success criteria, constraints, and automatic progress tracking. The system knows *what* it is trying to achieve.
- **Counterfactual Simulation**: Before executing high-risk actions (e.g., delete, deploy), the system hallucinates 2-3 possible outcomes, calculates risk scores, and chooses the safest path.
- **Self-Limitation Awareness**: "I'm not entirely certain." The system honestly reports confidence gaps and refuses to guess when stakes are high.
- **Authority Escalation**: A rigid 6-tier hierarchy (`Reflex` > `Safety` > `System` > `Mission` > `User` > `Agent`) ensuring the user always retains ultimate control.
- **Confidence Scoring**: Every plan comes with a visible confidence score (0-100%) and transparency into *why* the AI feels that way.
- **Persona Gateway**: Enforces a consistent JARVIS-like tone and brevity across all system outputs.
- **Narrator Agent**: Real-time internal voice providing status updates via Broca's area.
- **Reactive Preemption**: True task halting using `CancellationToken` for high-priority interrupts.
- **Psychological Pacing**: Intentional "thinking" delays modulated by task priority for perceived thoughtfulness.
- **Prediction Engine**: Anticipates user needs by preloading agents based on command history patterns.

### 12. Motor System & Muscles 🦾
- **Motor System**: Translates abstract intent into external actions via **Actuators**.
- **Actuators**:
  - **Appwrite Actuator**: Cloud muscle for serverless deployment/execution.
  - **Shell Actuator**: Machinary muscle for local command execution and robotics.
- **Effector Agent**: A specialized heavy-duty execution agent that controls the muscles.

### 13. Biological Dashboard (Visual Consciousness) 👁️
- **Organ Monitor**: Real-time visualization of metabolic states and organ health.
- **Volition Stream**: A live feed of the AI's "Stream of Consciousness" and internal drives.
- **Quarantine Zone**: visual management of agents locked by the Reflex System.

### 14. Dreaming Mode (Simulation & Optimization) 🌙
- **Sandboxed Analysis**: Offline, non-executing phase that runs during REM sleep to optimize system parameters without affecting production.
- **Core Capabilities**:
  - **Memory Consolidation**: Links cause→effect and organizes the knowledge vault.
  - **Failure Pattern Analysis**: Replays failures to detect recurring bugs or bottlenecks.
  - **Planner Simulation**: Dry-runs alternate execution paths to improve future planning efficiency.
  - **Rule Conflict Detection**: Finds overlapping, dead, or conflicting deterministic rules.
- **Human-in-the-Loop**: All AI suggestions are presented as **Recommendations** requiring explicit human approval before being applied.
- **Safety Kill-Switch**: Actuators are hard-locked, and any attempt to modify system state without approval triggers an immediate abort.

## 🛠️ Tech Stack & Architecture

- **Framework**: Flutter (Dart)
- **Biological Architecture**:
  - **Brain (Frontal Lobe)**: `PlannerAgent` (Planning & Routing).
  - **Memory (Hippocampus)**: `ReliabilityTracker` (Learning from success).
  - **Autonomic Nervous System**: `AutonomicSystem` (Heartbeat & Health).
  - **Circadian Rhythms**: `SleepManager` (Resource Optimization).
  - **Immune System**: `ImmuneSystem` (Active defense & Safe mode).
  - **Dreaming State**: `DreamingMode` (Simulation & Analysis).
  - **Spinal Cord (Reflexes)**: `ReflexSystem` (Instant safety).
  - **Muscles (Motor System)**: `MotorSystem` & `EffectorAgent` (External action).
  - **Social Integration**: `SocialAgent`, `SpeechOrgan` (Broca's/Wernicke's), & `ExternalInterfaces` (Webhooks, Appwrite).
  - **Dream Logic**: `DreamReport` & `DreamRecommendation` (Data structures for optimization).
  - **Limbic System (Emotions)**: `LimbicSystem` (PAD Model - Pleasure, Arousal, Dominance) for emotional context regulating agent responses.

## 🔮 Future Roadmap (Evolutionary Path)

The system is designed to evolve endlessly. Here are the next phases of life:

1.  **Reproduction (Mitosis)** 🦠
    *   *Concept*: Spawning independent "Child" isolates/processes to handle massive parallel tasks or survive system death.
2.  **Spatial Interface (VR/3D)** 🌌
    *   *Concept*: Visualizing the agent network as a 3D galaxy of nodes rather than a 2D graph.
3.  **Language Acquisition (Mirror Neurons)** 🗣️
    *   *Concept*: `SpeechOrgan` adapts its vocabulary and tone based on user interaction style.

## 🚀 Getting Started

1.  **Setup API Keys**: Add your OpenAI/Gemini keys in the Settings screen.
2.  **Configure Zones**: Set up storage zones in the **Storage Settings**.
3.  **Design your Flow**: Open the **Visual Orchestrator** and connect your agents.
4.  **Monitor Health**: Keep an eye on the **System Health** pulse on the dashboard.
5.  **Actuate**: Use the **Effector Agent** to deploy cloud functions or control hardware.

## 📝 Planned Improvements
- [ ] LLM-powered Graph Hallucination.
- [ ] Approval Nodes (Human-in-the-loop validation).
- [ ] Autonomous Background Task Optimization.

---
*Built for the future of agentic coding and knowledge management.*
