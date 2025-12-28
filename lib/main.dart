import 'package:appwrite/appwrite.dart';
import 'package:camera/camera.dart'; // Added camera import
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:my_app/calls/answering_screen.dart';
import 'package:my_app/calls/incoming_call_screen.dart';
import 'package:my_app/calls/outgoing_call_screen.dart';
import 'package:my_app/chat_screen.dart';
import 'package:my_app/environment.dart';
import 'package:my_app/profile_page.dart';
import 'package:my_app/results_searches.dart';
import 'package:my_app/sent_post_screen.dart';
import 'package:my_app/where_to_post.dart';
import 'package:my_app/where_to_post_story.dart';
import 'package:provider/provider.dart';

import 'add_post_screen.dart';
import 'add_to_story.dart';
import 'auth_service.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'chats_screen.dart';
import 'community_screen_widget/community_screen.dart';
import 'lens_screen.dart';
import 'sign_in.dart';
import 'sign_up.dart';
import 'otp_verification_screen.dart';
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
import 'package:my_app/about_searches_widgets/about_searches_widget.dart';
import 'package:my_app/adaptive_ui/adaptive_scaffold.dart';
import 'package:my_app/provider/queue_provider.dart';
import 'package:my_app/model/post.dart';
import 'package:my_app/full_screen_post_detail_page.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

List<CameraDescription> cameras = []; // Global cameras list

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permissions (especially for iOS)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    } else {
      debugPrint('User declined or has not accepted permission');
    }
  } catch (e) {
    debugPrint(
      'Firebase initialization failed: $e. Make sure google-services.json is added.',
    );
  }

  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Error initializing camera: $e');
  }

  final Client client = Client()
    ..setEndpoint(Environment.appwritePublicEndpoint)
    ..setProject(Environment.appwriteProjectId);

  final appwriteService = AppwriteService(client);
  final authService = AuthService(client);
  await authService.init();

  // Handle FCM token
  try {
    String? token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await appwriteService.registerDevice(token);
    }
  } catch (e) {
    debugPrint('Error getting FCM token: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: appwriteService),
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider(create: (_) => ThemeModel()),
        ChangeNotifierProvider(create: (_) => QueueProvider()),
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
      final isPublicRoute =
          state.matchedLocation == '/signin' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/verify-otp';

      // If the user is logged in and trying to access a public screen, redirect to home.
      if (loggedIn && isPublicRoute) {
        return '/';
      }

      // If the user is not logged in and not on a public screen, redirect to signin.
      if (!loggedIn && !isPublicRoute) {
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
          GoRoute(
            path: 'add_to_story',
            builder: (context, state) => const AddToStoryScreen(),
          ),
        ],
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
        path: '/verify-otp',
        builder: (context, state) {
          final extra = state.extra as Map<String, String>;
          return OTPVerificationScreen(
            userId: extra['userId']!,
            email: extra['email']!,
            name: extra['name']!,
            password: extra['password']!,
          );
        },
      ),
      GoRoute(
        path: '/where_to_post',
        builder: (context, state) =>
            WhereToPostScreen(postData: state.extra as Map<String, dynamic>),
      ),
      GoRoute(
        path: '/where_to_post_story',
        builder: (context, state) =>
            WhereToPostStoryScreen.fromQuery(state.uri.query),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/:id',
        builder: (context, state) => ProfileScreen(
          key: state.pageKey,
          userId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/profile_page/:id',
        builder: (context, state) => ProfilePageScreen(
          key: state.pageKey,
          profileId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/outgoing_call/:roomName',
        builder: (context, state) =>
            OutgoingCallScreen(roomName: state.pathParameters['roomName']!),
      ),
      GoRoute(
        path: '/incoming_call/:roomName',
        builder: (context, state) =>
            IncomingCallScreen(roomName: state.pathParameters['roomName']!),
      ),
      GoRoute(
        path: '/answering_call/:roomName',
        builder: (context, state) =>
            AnsweringScreen(roomName: state.pathParameters['roomName']!),
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
        builder: (context, state) =>
            SearchScreen(appwriteService: context.read<AppwriteService>()),
        routes: [
          GoRoute(
            path: ':query',
            builder: (context, state) =>
                ResultsSearches(query: state.pathParameters['query']!),
          ),
        ],
      ),
      GoRoute(
        path: '/chat/:userId',
        builder: (context, state) =>
            ChatScreen(receiverId: state.pathParameters['userId']!),
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
      GoRoute(
        path: '/sent_post',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final imagePaths = extra?['images'] as List<String>? ?? [];
          return SentPostScreen(imagePaths: imagePaths);
        },
      ),
      GoRoute(
        path: '/post/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final appwriteService = context.read<AppwriteService>();
          final authService = context.read<AuthService>();
          final profileId = authService.currentUser?.id ?? '';

          return FutureBuilder<Post>(
            future: appwriteService.getPost(id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Scaffold(
                  body: Center(child: Text('Error: ${snapshot.error}')),
                );
              }
              if (!snapshot.hasData) {
                return const Scaffold(
                  body: Center(child: Text('Post not found')),
                );
              }
              return FullScreenPostDetailPage(
                post: snapshot.data!,
                profileId: profileId,
              );
            },
          );
        },
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

  final List<String> _titles = ['Home', 'Chats', 'Search', 'Community', 'Lens'];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
        }
      },
      child: AdaptiveScaffold(
        selectedIndex: _selectedIndex,
        onIndexChanged: _onItemTapped,
        screens: _screens,
        title: _titles[_selectedIndex],
      ),
    );
  }
}
