import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../coordination/dreaming_mode.dart';
import '../specialized/systems/tone_modulator.dart';
import 'renderers/experiential_renderer.dart';

/// DreamStream Screensaver 🌌
///
/// A visual dashboard that runs while the system is "dreaming".
/// Features:
/// - Matrix-style "Code Rain" background
/// - Live stream of dream observations
/// - Pulse animation (heartbeat of the system)
class DreamStreamScreen extends StatefulWidget {
  final VoidCallback onWake;

  const DreamStreamScreen({super.key, required this.onWake});

  @override
  State<DreamStreamScreen> createState() => _DreamStreamScreenState();
}

class _DreamStreamScreenState extends State<DreamStreamScreen>
    with TickerProviderStateMixin {
  final DreamingMode _dreamingMode = DreamingMode();
  final List<String> _logs = []; // Live console logs
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _subscription;

  // Animation controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _startLogStream();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _startLogStream() {
    // In a real implementation, we would listen to DreamingMode.reportStream.
    // Ideally, DreamingMode exposes a specific stream for granular observations.
    // For now, we simulate the "Stream of Thought" if no active stream is available,
    // or hook into the report stream.

    _subscription = _dreamingMode.reportStream.listen((report) {
      for (final obs in report.observations) {
        _addLog(obs.description, obs.category);
      }
    });

    // Fallback simulation for visual flair if idle
    Timer.periodic(const Duration(milliseconds: 2000), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_dreamingMode.isDreaming) {
        _addLog(_generateThoughts(), 'subconscious');
      }
    });
  }

  String _generateThoughts() {
    final thoughts = [
      'Scanning neural pathways...',
      'Optimizing memory linkages...',
      'Detecting logic fragmentation...',
      'Re-indexing context graph...',
      'Simulating tactical outcome #482...',
      'Consolidating temporal patterns...',
      'Pruning low-confidence nodes...',
    ];
    return thoughts[Random().nextInt(thoughts.length)];
  }

  void _addLog(String message, String category) {
    if (!mounted) return;
    setState(() {
      final time = DateTime.now().toIso8601String().substring(11, 19);
      _logs.add('[$time] [$category] $message');
      if (_logs.length > 50) _logs.removeAt(0); // Keep buffer small
    });

    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tone = ToneModulator().determineTone(
      priorityLevel: 0, // Dreaming is low priority usually
      reliabilityScore: 1.0,
      isDreaming: true,
      // In a real app we'd pass UserContext too
    );
    final style = ToneModulator().getStyle(tone);
    final themeColor = Color(style.colorHex);

    return Scaffold(
      backgroundColor: const Color(0xFF000508), // Deepest Cyber Black
      body: Stack(
        children: [
          // 0. 3D Wireframe (Deep Background)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: ExperientialRenderer(
                    animationValue: _pulseController.value,
                    color: themeColor,
                  ),
                );
              },
            ),
          ),

          // 1. Matrix Code Rain (Background)
          Positioned.fill(child: _MatrixRain(color: themeColor)),

          // 2. Central Pulse (The Core)
          Center(
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      themeColor.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Foreground Interface
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DREAM PROTOCOL ACTIVE',
                            style: TextStyle(
                              fontFamily: 'Courier',
                              color: themeColor,
                              letterSpacing: 2.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'SYSTEM CONSOLIDATION IN PROGRESS',
                            style: TextStyle(
                              fontFamily: 'Courier',
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: widget.onWake,
                        icon: const Icon(Icons.power_settings_new),
                        color: Colors.white,
                        tooltip: 'Wake Logic Core',
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Live Log Terminal
                Container(
                  height: 300,
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    border: Border(
                      top: BorderSide(
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                  ),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          _logs[index],
                          style: TextStyle(
                            fontFamily: 'Courier',
                            color: themeColor.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // Instructions
                FadeTransition(
                  opacity: _pulseAnimation,
                  child: const Text(
                    'TAP TO WAKE',
                    style: TextStyle(
                      color: Colors.white30,
                      letterSpacing: 4.0,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),

          // Tap handler
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onWake,
              behavior: HitTestBehavior.translucent,
              child: Container(),
            ),
          ),
        ],
      ),
    );
  }
}

// Simple "Matrix Rain" effect
class _MatrixRain extends StatelessWidget {
  final Color color;
  const _MatrixRain({required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        // In a real app, this would be a CustomPainter or Shader
        // For now, we simulate the vibe with a subtle gradient overlay
        // to not kill performance during "dreaming"
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              const Color(0xFF0D0D1A).withValues(alpha: 0.8),
            ],
            stops: const [0.0, 0.8],
          ),
        ),
      ),
    );
  }
}
