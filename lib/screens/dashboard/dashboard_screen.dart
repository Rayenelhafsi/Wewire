import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart' as app_models;
import '../../services/firebase_service.dart';
import '../../services/session_service.dart';
import 'operator_dashboard.dart';
import 'quality_agent_dashboard.dart';
import 'maintenance_dashboard.dart';
import 'admin_dashboard.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  app_models.User? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Don't load user data here, wait for didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) {
      _loadUserData();
    }
  }

  void _loadUserData() async {
    // First check if user data was passed as arguments
    final argsUser =
        ModalRoute.of(context)?.settings.arguments as app_models.User?;

    if (argsUser != null) {
      setState(() {
        _user = argsUser;
        _isLoading = false;
      });
      return;
    }

    // If no arguments, check Firebase Auth for current user (for admins)
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        // Try to get user data from Firestore based on Firebase Auth user
        final adminData = await FirebaseService.getAdmin(currentUser.uid);
        if (adminData != null) {
          setState(() {
            _user = app_models.User(
              id: currentUser.uid,
              name: adminData['name'] ?? 'Admin User',
              email: currentUser.email ?? '',
              role: app_models.UserRole.admin,
              createdAt: DateTime.now(),
            );
            _isLoading = false;
          });
          return;
        }
      } catch (e) {
        debugPrint('Error loading admin data: $e');
      }
    }

    // If no Firebase Auth user or not an admin, check session storage for operators/technicians
    try {
      final sessionUser = await SessionService.getCurrentUser();
      if (sessionUser != null) {
        setState(() {
          _user = sessionUser;
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('Error loading session data: $e');
    }

    // If no user found anywhere, redirect to login
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_user == null) {
      // Redirect to login if no user data found
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', width: 150, height: 150),
            const SizedBox(width: 8),
            Text(
              'Welcome, ${_user!.name}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _handleLogout),
        ],
      ),
      body: _buildDashboardForRole(_user!),
    );
  }

  Future<void> _handleLogout() async {
    try {
      // Check for active sessions first
      final currentUser = await SessionService.getCurrentUser();
      if (currentUser != null) {
        final activeSessions =
            await FirebaseService.getActiveSessionsByOperator(currentUser.id);

        if (activeSessions.isNotEmpty) {
          // Show alert dialog if user has active sessions
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Active Session Detected'),
                content: const Text(
                  'You have an active session and cannot log out until you stop working. '
                  'Please complete or stop your current work session first.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
          return; // Don't proceed with logout
        }
      }

      // No active sessions, proceed with logout
      // Sign out from Firebase Auth (for admins)
      await FirebaseAuth.instance.signOut();

      // Clear session storage (for operators/technicians)
      await SessionService.clearSession();

      // Close any active sessions for the current user before logout (as backup)
      if (currentUser != null) {
        await FirebaseService.closeActiveSessionsForOperator(currentUser.id);
      }

      // Add a small delay to ensure signOut and clearSession complete
      await Future.delayed(const Duration(milliseconds: 300));

      Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDashboardForRole(app_models.User user) {
    switch (user.role) {
      case app_models.UserRole.operator:
        return OperatorDashboard(user: user);
      case app_models.UserRole.qualityAgent:
        return QualityAgentDashboard(user: user);
      case app_models.UserRole.maintenanceService:
        return MaintenanceDashboard(user: user);
      case app_models.UserRole.admin:
        return AdminDashboard(user: user);
    }
  }
}
