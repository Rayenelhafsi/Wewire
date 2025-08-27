import 'package:flutter/material.dart';
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
  print("Starting Firebase initialization...");
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print("Firebase initialized successfully.");
    } catch (e) {
      print("Error initializing Firebase: $e");
    }
  } else {
    print("Firebase is already initialized.");
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
    print('Failed to initialize notifications: $e');
    // Optionally, handle the error further (e.g., show a dialog)
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  // Check if user has an active session (for operators/technicians)
  Future<bool> _checkUserSession() async {
    try {
      final user = await SessionService.getCurrentUser();
      return user != null;
    } catch (e) {
      print('Error checking user session: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maintenance Communication System',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: FutureBuilder(
        future: Firebase.initializeApp(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
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
                        if (authSnapshot.connectionState ==
                            ConnectionState.active) {
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
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              },
            );
          }
          // Show loading indicator while initializing Firebase
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
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
