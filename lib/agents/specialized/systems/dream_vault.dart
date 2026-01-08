import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../coordination/dream_report.dart';

/// Dream Vault 🛌
///
/// Persistent storage for dream sessions.
/// separaties storage logic from the DreamingMode coordinator.
class DreamVault {
  static final DreamVault _instance = DreamVault._internal();
  factory DreamVault() => _instance;
  DreamVault._internal();

  String? _storagePath;
  final List<DreamSession> _history = [];

  List<DreamSession> get history => List.unmodifiable(_history);

  Future<void> initialize() async {
    final docsDir = await getApplicationDocumentsDirectory();
    _storagePath = p.join(docsDir.path, 'brain', 'dreams');

    final dir = Directory(_storagePath!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    await _load();
  }

  /// Save a completed session
  Future<void> saveSession(DreamSession session) async {
    // Add or update
    final index = _history.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      _history[index] = session;
    } else {
      _history.add(session);
    }
    await _save();
  }

  /// Get recent dreams
  List<DreamSession> getRecentDreams({int limit = 10}) {
    // Sort by date desc
    final sorted = List<DreamSession>.from(_history)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return sorted.take(limit).toList();
  }

  /// Get all pending recommendations
  List<DreamRecommendation> getPendingRecommendations() {
    final pending = <DreamRecommendation>[];
    for (final session in _history) {
      for (final report in session.reports) {
        pending.addAll(
          report.recommendations
              .where((r) => r.status == ApprovalStatus.pending),
        );
      }
    }
    return pending;
  }

  /// Update recommendation status
  Future<void> updateRecommendationStatus(
      String recommendationId, ApprovalStatus status,
      {String? note}) async {
    bool changed = false;
    for (final session in _history) {
      for (final report in session.reports) {
        for (final rec in report.recommendations) {
          if (rec.id == recommendationId) {
            rec.status = status;
            rec.reviewedAt = DateTime.now();
            if (note != null) rec.reviewNote = note;
            changed = true;
          }
        }
      }
    }

    if (changed) {
      await _save();
    }
  }

  Future<void> _load() async {
    if (_storagePath == null) return;
    final file = File(p.join(_storagePath!, 'dream_history.json'));
    if (!await file.exists()) return;

    try {
      final content = await file.readAsString();
      final List<dynamic> json = jsonDecode(content);
      _history.clear();
      _history.addAll(
        json.map((j) => DreamSession.fromJson(j as Map<String, dynamic>)),
      );
    } catch (e) {
      // ignore error
    }
  }

  Future<void> _save() async {
    if (_storagePath == null) return;
    final file = File(p.join(_storagePath!, 'dream_history.json'));
    final json = jsonEncode(_history.map((s) => s.toJson()).toList());
    await file.writeAsString(json);
  }
}
