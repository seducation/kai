import 'package:flutter/material.dart';
import 'package:my_app/srv_aimode_tabscreen.dart';
import 'package:my_app/srv_app_tabscreen.dart';
import 'package:my_app/srv_chats_tabscreen.dart';
import 'package:my_app/srv_feature_tabscreen.dart';
import 'package:my_app/srv_files_tabscreen.dart';
import 'package:my_app/srv_following_tabscreen.dart';
import 'package:my_app/srv_forum_tabscreen.dart';
import 'package:my_app/srv_music_tabscreen.dart';
import 'package:my_app/srv_photos_tabscreen.dart';
import 'package:my_app/srv_searchtools_tabscreen.dart';
import 'package:my_app/srv_videos_tabscreen.dart';

class ResultsSearches extends StatefulWidget {
  final String query;

  const ResultsSearches({super.key, required this.query});

  @override
  State<ResultsSearches> createState() => _ResultsSearchesState();
}

class _ResultsSearchesState extends State<ResultsSearches> with TickerProviderStateMixin {
  late TextEditingController _searchController;
  late TabController _mainTabController;
  String _currentQuery = '';

  final List<String> _tabs = [
    'ai mode',
    'feature',
    'app',
    'files',
    'following',
    'forum',
    'music',
    'photos',
    'chats',
    'search tools',
    'videos',
  ];

  final List<Widget> _tabScreens = [
    const SrvAimodeTabscreen(),
    const SrvFeatureTabscreen(),
    const SrvAppTabscreen(),
    const SrvFilesTabscreen(),
    const SrvFollowingTabscreen(),
    const SrvForumTabscreen(),
    const SrvMusicTabscreen(),
    const SrvPhotosTabscreen(),
    const SrvChatsTabscreen(),
    const SrvSearchtoolsTabscreen(),
    const SrvVideosTabscreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentQuery = widget.query;
    _searchController = TextEditingController(text: _currentQuery);
    _mainTabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mainTabController.dispose();
    super.dispose();
  }

  void _updateSearchQuery(String newQuery) {
    setState(() {
      _currentQuery = newQuery;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration.collapsed(
            hintText: 'Search',
          ),
          onChanged: (value) {
            setState(() {});
          },
          onSubmitted: _updateSearchQuery,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _updateSearchQuery(_searchController.text),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _mainTabController,
          isScrollable: true,
          tabs: _tabs.map((String name) => Tab(text: name)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _mainTabController,
        children: _tabScreens,
      ),
    );
  }
}
