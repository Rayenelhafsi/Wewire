import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth/landing_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/matricule_login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/chat/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maintenance Communication System',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LandingScreen(),
        '/admin-login': (context) => const LoginScreen(),
        '/matricule-login': (context) => const MatriculeLoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/chat': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
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
