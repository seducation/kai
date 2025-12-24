import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'hmv_features_tabscreen.dart';
import 'hmv_following_tabscreen.dart';
import 'hmv_news_tabscreen.dart';
import 'hmv_shorts_tabscreen.dart';
import 'hmv_videos_tabscreen.dart';
import 'hmv_forum_tabscreen.dart';
import 'hmv_question_tabscreen.dart';
import 'chats_screen.dart';
import 'tab_manager_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _mainTabController;
  final ScrollController _scrollController = ScrollController();
  late List<GlobalKey> _tabKeys;

  // Make the list of tabs mutable
  final List<String> _tabs = [
    'shorts',
    'feature',
    'videos',
    'news',
    'following',
    'questions',
    'files',
    'forum',
    'music',
    'photos',
    'chats',
    'search tools',
  ];

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    _tabKeys = List.generate(_tabs.length, (_) => GlobalKey());
    _mainTabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: 1,
    );
  }

  void _recreateController(VoidCallback fn) {
    final oldIndex = _mainTabController.index;
    _mainTabController.dispose(); // Dispose the old controller
    setState(() {
      fn(); // Perform the state change (add/remove tab)
      _initializeController(); // Create a new controller
      // Try to restore the previous index if it's still valid
      _mainTabController.index = (oldIndex < _tabs.length)
          ? oldIndex
          : _tabs.length - 1;
    });
  }

  void _onAddTab(String newTab) {
    _recreateController(() {
      _tabs.add(newTab);
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    // The TabManagerScreen only shows reorderable tabs, so we offset the index.
    const int unMovableTabs = 2; // 'shorts' and 'feature'
    final int effectiveOldIndex = oldIndex + unMovableTabs;
    int effectiveNewIndex = newIndex + unMovableTabs;

    setState(() {
      if (effectiveOldIndex < effectiveNewIndex) {
        effectiveNewIndex -= 1;
      }
      final item = _tabs.removeAt(effectiveOldIndex);
      _tabs.insert(effectiveNewIndex, item);
    });
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _mainTabController,
      builder: (context, child) {
        return PopScope(
          canPop: _mainTabController.index == 1,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_mainTabController.index != 1) {
              _mainTabController.animateTo(1);
            }
          },
          child: _buildScaffold(context),
        );
      },
    );
  }

  Widget _buildScaffold(BuildContext context) {
    if (!_mainTabController.indexIsChanging) {
      final tabIndex = _mainTabController.index;
      if (tabIndex > 0) {
        final key = _tabKeys[tabIndex];
        final context = key.currentContext;
        if (context != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Scrollable.ensureVisible(
              context,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: 0.5,
            );
          });
        }
      }
    }

    final theme = Theme.of(context);
    final selectedColor =
        theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface;
    final unselectedColor = theme.unselectedWidgetColor;

    final tabBarWidget = Row(
      children: [
        InkWell(
          onTap: () => _mainTabController.animateTo(0),
          child: Container(
            key: _tabKeys[0],
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            alignment: Alignment.center,
            child: Text(
              'shorts',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: _mainTabController.index == 0
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: _mainTabController.index == 0
                    ? selectedColor
                    : unselectedColor,
                shadows: [
                  Shadow(
                    blurRadius: 2.0,
                    color: Colors.black.withAlpha(128),
                    offset: const Offset(1.0, 1.0),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_tabs.length - 1, (index) {
                final tabIndex = index + 1;
                final isSelected = _mainTabController.index == tabIndex;
                return InkWell(
                  onTap: () => _mainTabController.animateTo(tabIndex),
                  child: Container(
                    key: _tabKeys[tabIndex],
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    alignment: Alignment.center,
                    child: Text(
                      _tabs[tabIndex],
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? selectedColor : unselectedColor,
                        shadows: [
                          Shadow(
                            blurRadius: 2.0,
                            color: Colors.black.withAlpha(128),
                            offset: const Offset(1.0, 1.0),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );

    final tabBarView = TabBarView(
      controller: _mainTabController,
      dragStartBehavior: DragStartBehavior.start,
      children: _tabs.map<Widget>((name) {
        if (name == 'search tools') {
          // The reorderable part of the list excludes the first 2 tabs.
          final reorderableTabs = _tabs.sublist(2);
          return TabManagerScreen(
            tabs: reorderableTabs,
            onReorder: _onReorder,
            onAddTab: _onAddTab,
          );
        } else if (name == 'chats') {
          return const ChatsScreen();
        } else if (name == 'shorts') {
          return const HMVShortsTabscreen();
        } else if (name == 'feature') {
          return const HMVFeaturesTabscreen();
        } else if (name == 'videos') {
          return const HmvVideosTabScreen();
        } else if (name == 'news') {
          return const HMVNewsTabscreen();
        } else if (name == 'following') {
          return const HMVFollowingTabscreen();
        } else if (name == 'forum') {
          return const HmvForumTabscreen();
        } else if (name == 'questions') {
          return const HmvQuestionTabscreen();
        } else {
          return Center(child: Text(name));
        }
      }).toList(),
    );

    if (_mainTabController.index == 0) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withAlpha(179), Colors.transparent],
              ),
            ),
          ),
          title: SizedBox(height: kToolbarHeight, child: tabBarWidget),
          titleSpacing: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => context.push('/search'),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                context.push('/add_post');
              },
            ),
          ],
        ),
        body: tabBarView,
      );
    } else {
      const String currentTitle = 'gvone';

      return Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                leadingWidth: 112,
                leading: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () {
                        context.push('/profile');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.shopping_cart_outlined),
                      tooltip: 'Shop',
                      onPressed: () {},
                    ),
                  ],
                ),
                title: Text(currentTitle),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => context.push('/search'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      context.push('/add_post');
                    },
                  ),
                ],
                floating: true,
                snap: true,
                pinned: false,
                elevation: 0,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(kToolbarHeight),
                  child: ClipRect(
                    child: SizedBox(
                      height: kToolbarHeight,
                      child: tabBarWidget,
                    ),
                  ),
                ),
              ),
            ];
          },
          body: tabBarView,
        ),
      );
    }
  }
}
