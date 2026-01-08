import 'package:flutter/material.dart';
import '../specialized/systems/explainability_engine.dart';
import '../specialized/systems/narrative_generator.dart';

/// Explainability Screen 💡
///
/// Allows the user to inspect the system's decision history ("Why did you do that?").
class ExplainabilityScreen extends StatefulWidget {
  const ExplainabilityScreen({super.key});

  @override
  State<ExplainabilityScreen> createState() => _ExplainabilityScreenState();
}

class _ExplainabilityScreenState extends State<ExplainabilityScreen> {
  final ExplainabilityEngine _engine = ExplainabilityEngine();
  DecisionTrace? _selectedTrace;

  @override
  Widget build(BuildContext context) {
    final traces = _engine.recentTraces;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('🧠 Explainability'),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: Row(
        children: [
          // Left: Decision List
          Expanded(
            flex: 2,
            child: ListView.builder(
              itemCount: traces.length,
              itemBuilder: (context, index) {
                final trace = traces[index];
                return ListTile(
                  title: Text(
                    trace.intent,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${trace.finalOutcome} • ${trace.timestamp.hour}:${trace.timestamp.minute}',
                    style: TextStyle(
                      color: _getOutcomeColor(trace.finalOutcome),
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedTrace = trace;
                    });
                  },
                  selected: _selectedTrace == trace,
                  selectedTileColor: Colors.blue.withAlpha(50),
                );
              },
            ),
          ),

          const VerticalDivider(width: 1, color: Color(0xFF334155)),

          // Right: Detail View (Why Chain)
          Expanded(
            flex: 3,
            child: _selectedTrace == null
                ? const Center(
                    child: Text(
                      'Select a decision to inspect',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : _buildDetailView(_selectedTrace!),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailView(DecisionTrace trace) {
    final narrative = NarrativeGenerator.explainDecision(trace);
    final whyChain = WhyChain(trace);

    return Container(
      padding: const EdgeInsets.all(24),
      color: const Color(0xFF1E293B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Narrative Summary
          Text(
            'The "Why"',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            narrative,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          const Divider(color: Color(0xFF334155)),
          const SizedBox(height: 16),

          // 2. Factor Breakdown
          Text(
            'Decision Factors',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                if (whyChain.blockers.isNotEmpty) ...[
                  const Text('🛑 Blockers',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...whyChain.blockers.map((f) => _buildFactorCard(f)),
                  const SizedBox(height: 24),
                ],
                if (whyChain.supporters.isNotEmpty) ...[
                  const Text('✅ Supporters',
                      style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...whyChain.supporters.map((f) => _buildFactorCard(f)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorCard(DecisionFactor factor) {
    return Card(
      color: const Color(0xFF334155),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          factor.weight < 0 ? Icons.block : Icons.check_circle,
          color: factor.weight < 0 ? Colors.redAccent : Colors.greenAccent,
        ),
        title: Text(
          factor.reason,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          'Source: ${factor.source} • Weight: ${factor.weight}',
          style: TextStyle(color: Colors.grey[400]),
        ),
      ),
    );
  }

  Color _getOutcomeColor(String outcome) {
    switch (outcome) {
      case 'Approved':
        return Colors.greenAccent;
      case 'Blocked':
        return Colors.redAccent;
      default:
        return Colors.orangeAccent;
    }
  }
}
