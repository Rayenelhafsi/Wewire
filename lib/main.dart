import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/auth/landing_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/matricule_login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'services/notification_service.dart';
import 'services/firebase_service.dart';
import 'services/session_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("Starting Firebase initialization...");

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("Firebase initialized successfully.");
    } else {
      debugPrint("Firebase is already initialized.");
    }
  } catch (e) {
    debugPrint("Error initializing Firebase: $e");
  }

  runApp(const MainApp());

  // Initialize notification service after app starts (non-blocking)
  _initializeNotifications();
}

// Initialize notifications after app starts to prevent blocking
void _initializeNotifications() async {
  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('Failed to initialize notifications: $e');
    // Optionally, handle the error further (e.g., show a dialog)
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Maintenance Communication System',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'TitilliumWeb',
      ),
      home: const SplashScreen(),
      routes: {
        '/admin-login': (context) => const LoginScreen(),
        '/matricule-login': (context) => const MatriculeLoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/chat': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>?;

          if (args != null && args['isPrivateChat'] == true) {
            return ChatScreen(
              chatId: args['chatId'],
              isPrivateChat: true,
              title: args['title'],
              user: args['user'],
            );
          } else {
            // For issue chats
            return ChatScreen(
              chatId: args?['issueId'] ?? '',
              isPrivateChat: false,
              title: args?['title'] ?? 'Chat',
              issue: args?['issue'],
              user: args?['user'],
            );
          }
        },
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Check if user has an active session (for operators/technicians)
  Future<bool> _checkUserSession() async {
    try {
      final user = await SessionService.getCurrentUser();
      return user != null;
    } catch (e) {
      debugPrint('Error checking user session: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkUserSession(),
      builder: (context, sessionSnapshot) {
        if (sessionSnapshot.connectionState == ConnectionState.done) {
          if (sessionSnapshot.data == true) {
            // User has active session, navigate to dashboard
            return const DashboardScreen();
          } else {
            // No session found, check Firebase Auth
            return StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, authSnapshot) {
                if (authSnapshot.connectionState == ConnectionState.active) {
                  final User? user = authSnapshot.data;
                  if (user != null) {
                    // User is logged in via Firebase Auth, navigate to dashboard
                    return const DashboardScreen();
                  } else {
                    // User is not logged in, show landing screen
                    return const LandingScreen();
                  }
                }
                // Show loading indicator while checking auth state
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              },
            );
          }
        }
        // Show loading indicator while checking session
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_animationController);
    _animationController.forward();

    // Navigate to main screen after 1 second
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white, // Or your app's background color
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Image.asset(
              'assets/images/logo.png',
              width: 300, // Adjust size as needed
              height: 400,
            ),
          ),
        ),
      ),
    );
  }
}
