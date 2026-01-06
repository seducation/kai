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
- **State Persistence**: Survival through restarts; the controller saves its runtime state (retry counts, queue status) to the vault.

### 5. Adaptive UI 📱💻
- **Responsive Layout**:
  - **Desktop/Tablet**: Full interactive Graph Editor.
  - **Mobile**: Automatically switches to an **Execution Timeline (Feed View)** for easy monitoring on small screens.

## 🛠️ Tech Stack & Architecture

- **Framework**: Flutter (Dart)
- **Architecture**:
  - **ControllerAgent**: The brain that orchestrates the workflow.
  - **AgentBase**: Enforces the "Action → Log → Result" rule (Transparancy).
  - **StorageAgent**: Manages the local file system Knowledge Vault.
  - **AppwriteFunctionAgent**: Specialized agent for executing serverless-style logic.
- **Models**: Unified `AgentGraph`, `GraphNode`, and `AgentStep` schemas.

## 🚀 Getting Started

1. **Setup API Keys**: Add your OpenAI/Gemini keys in the Settings screen.
2. **Design your Flow**: Open the **Visual Orchestrator** and connect your agents.
3. **Run**: Click Play and watch the system execute.
4. **Inspect Vault**: Check the `documents/vault/` directory on your device to see the persistent knowledge generated.

## 📝 Planned Improvements
- [ ] LLM-powered Graph Hallucination (generating entire workflows from a single prompt).
- [ ] Approval Nodes (Human-in-the-loop validation).
- [ ] Advanced Type Casting between incompatible ports.

---
*Built for the future of agentic coding and knowledge management.*
