import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:my_app/chat_screen.dart';
import 'package:my_app/environment.dart';
import 'package:my_app/results_searches.dart';
import 'package:my_app/where_to_post.dart';
import 'package:provider/provider.dart';

import 'add_post_screen.dart';
import 'auth_service.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'chats_screen.dart';
import 'community_screen_widget/community_screen.dart';
import 'lens_screen.dart';
import 'sign_in.dart';
import 'sign_up.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'setting_personal_info_screen.dart';
import 'theme_model.dart';
import 'setting_active_status_screen.dart';
import 'setting_app_permission_screen.dart';
import 'setting_delete_screen.dart';
import 'setting_emergency_screen.dart';
import 'setting_theme_screen.dart';
import 'setting_location_screen.dart';
import 'setting_privacy_screen.dart';
import 'setting_safety_screen.dart';
import 'setting_support_screen.dart';
import 'about_searches_widgets/about_searches_widget.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final Client client = Client()
    ..setEndpoint(Environment.appwritePublicEndpoint)
    ..setProject(Environment.appwriteProjectId)
    ..setSelfSigned(status: true); // This is the line I added

  final authService = AuthService(client);
  await authService.init();

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => AppwriteService(client)),
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider(create: (_) => ThemeModel()),
      ],
      child: MyApp(authService: authService),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AuthService authService;
  const MyApp({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    final router = _createRouter(authService);

    return Consumer<ThemeModel>(
      builder: (context, theme, child) {
        return MaterialApp.router(
          routerConfig: router,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: theme.themeMode,
        );
      },
    );
  }
}

GoRouter _createRouter(AuthService authService) {
  return GoRouter(
    refreshListenable: authService,
    redirect: (BuildContext context, GoRouterState state) {
      final loggedIn = authService.isLoggedIn;
      final isLoggingIn = state.matchedLocation == '/signin' || state.matchedLocation == '/signup';

      // If the user is logged in and trying to access a login screen, redirect to home.
      if (loggedIn && isLoggingIn) {
        return '/';
      }

      // If the user is not logged in and not on a login screen, redirect to signin.
      if (!loggedIn && !isLoggingIn) {
        return '/signin';
      }

      // No redirect needed.
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const MainScreen(),
        routes: [
          GoRoute(
            path: 'add_post',
            builder: (context, state) => const AddPostScreen(),
          ),
        ]
      ),
      GoRoute(
        path: '/signin',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
       GoRoute(
        path: '/where_to_post',
        builder: (context, state) => WhereToPostScreen(postData: state.extra as Map<String, dynamic>),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
       GoRoute(
        path: '/profile/:id',
        builder: (context, state) => ProfileScreen(key: state.pageKey, userId: state.pathParameters['id']!),
      ),
       GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/setting_personal_info',
        builder: (context, state) => const SettingPersonalInfoScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => SearchScreen(appwriteService: context.read<AppwriteService>()),
        routes: [
          GoRoute(
            path: ':query',
            builder: (context, state) => ResultsSearches(
              query: state.pathParameters['query']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/chat/:userId',
        builder: (context, state) => ChatScreen(
          receiverId: state.pathParameters['userId']!,
        ),
      ),
       GoRoute(
        path: '/setting_active_status',
        builder: (context, state) => const SettingActiveStatusScreen(),
      ),
      GoRoute(
        path: '/setting_app_permission',
        builder: (context, state) => const SettingAppPermissionScreen(),
      ),
      GoRoute(
        path: '/setting_delete',
        builder: (context, state) => const SettingDeleteScreen(),
      ),
      GoRoute(
        path: '/setting_emergency',
        builder: (context, state) => const SettingEmergencyScreen(),
      ),
      GoRoute(
        path: '/setting_theme',
        builder: (context, state) => const SettingThemeScreen(),
      ),
      GoRoute(
        path: '/setting_location',
        builder: (context, state) => const SettingLocationScreen(),
      ),
      GoRoute(
        path: '/setting_privacy',
        builder: (context, state) => const SettingPrivacyScreen(),
      ),
      GoRoute(
        path: '/setting_safety',
        builder: (context, state) => const SettingSafetyScreen(),
      ),
      GoRoute(
        path: '/setting_support',
        builder: (context, state) => const SettingSupportScreen(),
      ),
    ],
  );
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ChatsScreen(),
    const AboutSearches(),
    const CommunityScreen(),
    const LensScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera),
            label: 'Lens',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
