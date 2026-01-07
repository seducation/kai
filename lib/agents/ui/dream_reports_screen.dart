import 'package:flutter/material.dart';
import '../coordination/dreaming_mode.dart';
import '../coordination/dream_report.dart';

/// Screen to display dream analysis reports and manage recommendations.
///
/// Features:
/// - List of dream sessions with expandable details
/// - Observations with confidence scores
/// - Recommendations with approve/reject/defer buttons
/// - Dream history timeline
class DreamReportsScreen extends StatefulWidget {
  const DreamReportsScreen({super.key});

  @override
  State<DreamReportsScreen> createState() => _DreamReportsScreenState();
}

class _DreamReportsScreenState extends State<DreamReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DreamingMode _dreamingMode = DreamingMode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initialize();
  }

  Future<void> _initialize() async {
    await _dreamingMode.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        title: const Row(
          children: [
            Text('🌙 ', style: TextStyle(fontSize: 24)),
            Text(
              'Dream Reports',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF9F7AEA),
          labelColor: const Color(0xFF9F7AEA),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Pending', icon: Icon(Icons.pending_actions, size: 18)),
            Tab(text: 'Sessions', icon: Icon(Icons.history, size: 18)),
            Tab(text: 'Status', icon: Icon(Icons.monitor_heart, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(),
          _buildSessionsTab(),
          _buildStatusTab(),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    final pending = _dreamingMode.getPendingRecommendations();

    if (pending.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline,
        title: 'No Pending Recommendations',
        subtitle:
            'Dream analysis will generate recommendations during idle time',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pending.length,
      itemBuilder: (context, index) {
        return _RecommendationCard(
          recommendation: pending[index],
          onApprove: () => _approveRecommendation(pending[index]),
          onReject: () => _rejectRecommendation(pending[index]),
          onDefer: () => _deferRecommendation(pending[index]),
        );
      },
    );
  }

  Widget _buildSessionsTab() {
    final sessions = _dreamingMode.sessionHistory;

    if (sessions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.nightlight_round,
        title: 'No Dream Sessions Yet',
        subtitle: 'Sessions will appear after the system enters deep sleep',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[sessions.length - 1 - index]; // Reverse order
        return _SessionCard(session: session);
      },
    );
  }

  Widget _buildStatusTab() {
    final isDreaming = _dreamingMode.isDreaming;
    final currentSession = _dreamingMode.currentSession;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Status Card
          _StatusCard(
            title: 'Dreaming Mode Status',
            status: isDreaming ? 'Active' : 'Idle',
            statusColor: isDreaming ? Colors.purple : Colors.grey,
            icon: isDreaming ? Icons.auto_awesome : Icons.bedtime,
          ),
          const SizedBox(height: 16),

          // Safety Constraints Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2D2D44)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.security, color: Color(0xFF48BB78), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Safety Constraints',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildConstraintRow('Actuators Disabled', true),
                _buildConstraintRow('Reflex System Active', true),
                _buildConstraintRow('Read-Only Vault', true),
                _buildConstraintRow('No Priority Changes', true),
                _buildConstraintRow('No Rule Auto-Creation', true),
                _buildConstraintRow('Human Approval Required', true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Current Session Info
          if (currentSession != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF9F7AEA).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Dream Session',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Started: ${_formatTime(currentSession.startTime)}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  Text(
                    'Reports: ${currentSession.reports.length}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  Text(
                    'Observations: ${currentSession.totalObservations}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          const Text(
            'About Dreaming Mode',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dreaming Mode is an offline, sandboxed optimization phase:',
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 12),
                _AboutItem(emoji: '🧹', text: 'Garbage collection'),
                _AboutItem(emoji: '📋', text: 'Log review & analysis'),
                _AboutItem(emoji: '🔧', text: 'Dry-run refactoring'),
                _AboutItem(emoji: '🔮', text: 'What-if analysis'),
                _AboutItem(emoji: '🧠', text: 'Memory consolidation'),
                SizedBox(height: 12),
                Text(
                  'All recommendations require human approval.\nNo autonomous changes are made.',
                  style: TextStyle(color: Color(0xFF48BB78), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConstraintRow(String label, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.cancel,
            color: isActive ? const Color(0xFF48BB78) : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white70 : Colors.red,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _approveRecommendation(DreamRecommendation rec) async {
    await _dreamingMode.approveRecommendation(rec.id);
    if (mounted) setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Approved: ${rec.title}'),
          backgroundColor: const Color(0xFF48BB78),
        ),
      );
    }
  }

  Future<void> _rejectRecommendation(DreamRecommendation rec) async {
    final reason = await _showRejectDialog();
    if (reason != null) {
      await _dreamingMode.rejectRecommendation(rec.id, reason);
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rejected: ${rec.title}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deferRecommendation(DreamRecommendation rec) async {
    await _dreamingMode.deferRecommendation(rec.id);
    if (mounted) setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deferred: ${rec.title}'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Reject Recommendation',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Reason for rejection...',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              controller.text.isEmpty ? 'No reason provided' : controller.text,
            ),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }
}

// =============================================================================
// WIDGET COMPONENTS
// =============================================================================

class _RecommendationCard extends StatelessWidget {
  final DreamRecommendation recommendation;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDefer;

  const _RecommendationCard({
    required this.recommendation,
    required this.onApprove,
    required this.onReject,
    required this.onDefer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF9F7AEA).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _getTypeIcon(recommendation.type),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  recommendation.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            recommendation.description,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onDefer,
                child: const Text(
                  'Defer',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
              TextButton(
                onPressed: onReject,
                child: const Text(
                  'Reject',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onApprove,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF48BB78),
                ),
                child: const Text('Approve'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _getTypeIcon(RecommendationType type) {
    switch (type) {
      case RecommendationType.newRule:
        return const Icon(Icons.add_circle, color: Color(0xFF9F7AEA), size: 20);
      case RecommendationType.modifyRule:
        return const Icon(Icons.edit, color: Color(0xFF9F7AEA), size: 20);
      case RecommendationType.removeRule:
        return const Icon(Icons.remove_circle, color: Colors.orange, size: 20);
      case RecommendationType.memoryLink:
        return const Icon(Icons.link, color: Color(0xFF48BB78), size: 20);
      case RecommendationType.insight:
        return const Icon(Icons.lightbulb, color: Color(0xFFF6E05E), size: 20);
    }
  }
}

class _SessionCard extends StatefulWidget {
  final DreamSession session;

  const _SessionCard({required this.session});

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2D2D44)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _getStatusIcon(session.status),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(session.startTime),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${session.reports.length} reports • '
                          '${session.totalObservations} observations',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(color: Color(0xFF2D2D44), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: session.reports.map((report) {
                  return _ReportItem(report: report);
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _getStatusIcon(DreamStatus status) {
    switch (status) {
      case DreamStatus.running:
        return const Icon(Icons.sync, color: Colors.blue, size: 24);
      case DreamStatus.completed:
        return const Icon(Icons.check_circle,
            color: Color(0xFF48BB78), size: 24);
      case DreamStatus.interrupted:
        return const Icon(Icons.pause_circle, color: Colors.orange, size: 24);
      case DreamStatus.safetyTriggered:
        return const Icon(Icons.warning, color: Colors.red, size: 24);
    }
  }

  String _formatDate(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-'
        '${time.day.toString().padLeft(2, '0')} at '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }
}

class _ReportItem extends StatelessWidget {
  final DreamReport report;

  const _ReportItem({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _getCapabilityIcon(report.capability),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getCapabilityName(report.capability),
                  style: const TextStyle(color: Colors.white),
                ),
                Text(
                  '${report.observations.length} observations, '
                  '${report.recommendations.length} recommendations',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getCapabilityIcon(DreamCapability capability) {
    switch (capability) {
      case DreamCapability.memoryConsolidation:
        return const Icon(Icons.memory, color: Color(0xFF9F7AEA), size: 20);
      case DreamCapability.failurePatternAnalysis:
        return const Icon(Icons.bug_report, color: Colors.orange, size: 20);
      case DreamCapability.plannerSimulation:
        return const Icon(Icons.route, color: Colors.blue, size: 20);
      case DreamCapability.ruleConflictDetection:
        return const Icon(Icons.rule, color: Color(0xFF48BB78), size: 20);
    }
  }

  String _getCapabilityName(DreamCapability capability) {
    switch (capability) {
      case DreamCapability.memoryConsolidation:
        return 'Memory Consolidation';
      case DreamCapability.failurePatternAnalysis:
        return 'Failure Pattern Analysis';
      case DreamCapability.plannerSimulation:
        return 'Planner Simulation';
      case DreamCapability.ruleConflictDetection:
        return 'Rule Conflict Detection';
    }
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String status;
  final Color statusColor;
  final IconData icon;

  const _StatusCard({
    required this.title,
    required this.status,
    required this.statusColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: statusColor, size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AboutItem extends StatelessWidget {
  final String emoji;
  final String text;

  const _AboutItem({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
