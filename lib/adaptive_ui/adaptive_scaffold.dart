import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:my_app/provider/queue_provider.dart';
import 'package:my_app/adaptive_ui/nav_rail_sidebar.dart';
import 'package:my_app/adaptive_ui/bottom_nav_pane.dart';
import 'package:my_app/adaptive_ui/extra_info_pane.dart';
import 'package:my_app/adaptive_ui/master_list_pane.dart';

/// A robust adaptive shell for the application.
class AdaptiveScaffold extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final List<Widget> screens;
  final String title;

  const AdaptiveScaffold({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.screens,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Breakpoints optimized for Mobile, Tablet, and Desktop
        if (constraints.maxWidth < 600) {
          return _buildMobile(context);
        } else if (constraints.maxWidth < 1100) {
          // Tablet / Medium Screen
          return _buildTablet(context);
        } else {
          // Desktop / Large Screen
          return _buildLarge(context);
        }
      },
    );
  }

  /// 1. Mobile (< 600px): BottomNav + Single Screen
  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      body: screens[selectedIndex],
      bottomNavigationBar: BottomNavPane(
        selectedIndex: selectedIndex,
        onDestinationSelected: onIndexChanged,
      ),
    );
  }

  /// 2. Tablet / Medium (600px - 1100px): NavRail + Two Panes
  Widget _buildTablet(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavRailSidebar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onIndexChanged,
          ),
          const VerticalDivider(width: 1, thickness: 1),
          // Pane 1: Master List (Left Screen)
          Expanded(
            flex: 3,
            child: Column(
              children: [
                AppBar(
                  elevation: 0,
                  title: const Text('Activity'),
                  actions: [
                    Consumer<QueueProvider>(
                      builder: (context, queueProvider, child) {
                        return IconButton(
                          icon: const Icon(Icons.clear_all),
                          onPressed: () => queueProvider.clearQueue(),
                        );
                      },
                    ),
                  ],
                ),
                Expanded(
                  child: Consumer<QueueProvider>(
                    builder: (context, queueProvider, child) {
                      if (queueProvider.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (queueProvider.queueItems.isEmpty) {
                        return const Center(child: Text('Add posts to queue'));
                      }
                      return MasterListPane(
                        items: queueProvider.queueItems
                            .map((e) => e['label'] ?? '')
                            .toList(),
                        selectedId: null,
                        onItemSelected: (index) {
                          final postId = queueProvider.queueItems[index]['id'];
                          if (postId != null) {
                            context.push('/post/$postId');
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          // Pane 2: Primary Content (Main Screen)
          Expanded(
            flex: 7,
            child: Column(
              children: [
                AppBar(elevation: 0, title: Text(title)),
                Expanded(child: screens[selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Large Screens (> 1100px): NavRail + Three Panes (Stable Layout)
  Widget _buildLarge(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NavRailSidebar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onIndexChanged,
          ),
          const VerticalDivider(width: 1, thickness: 1),
          // Pane 1: Master List (Left Screen - Consistent with Tablet)
          Expanded(
            flex: 3,
            child: Column(
              children: [
                AppBar(
                  elevation: 0,
                  title: const Text('Activity'),
                  actions: [
                    Consumer<QueueProvider>(
                      builder: (context, queueProvider, child) {
                        return IconButton(
                          icon: const Icon(Icons.clear_all),
                          onPressed: () => queueProvider.clearQueue(),
                        );
                      },
                    ),
                  ],
                ),
                Expanded(
                  child: Consumer<QueueProvider>(
                    builder: (context, queueProvider, child) {
                      if (queueProvider.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (queueProvider.queueItems.isEmpty) {
                        return const Center(child: Text('Add posts to queue'));
                      }
                      return MasterListPane(
                        items: queueProvider.queueItems
                            .map((e) => e['label'] ?? '')
                            .toList(),
                        selectedId: null,
                        onItemSelected: (index) {
                          final postId = queueProvider.queueItems[index]['id'];
                          if (postId != null) {
                            context.push('/post/$postId');
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          // Pane 2: Primary Content (Main Screen)
          Expanded(
            flex: 5,
            child: Column(
              children: [
                AppBar(elevation: 0, title: Text(title)),
                Expanded(child: screens[selectedIndex]),
              ],
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          // Pane 3: Analytic/Extra Info (Right Screen)
          const Expanded(flex: 3, child: ExtraInfoPane()),
        ],
      ),
    );
  }
}
