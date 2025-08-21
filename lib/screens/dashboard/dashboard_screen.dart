import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import 'operator_dashboard.dart';
import 'quality_agent_dashboard.dart';
import 'maintenance_dashboard.dart';
import 'admin_dashboard.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    if (args == null) {
      // Handle the case where arguments are null (e.g., redirect to login)
      return const Scaffold(
        body: Center(child: Text('No user data found. Please login again.')),
      );
    }
    
    // Convert the map to a User object
    final user = User(
      id: args['matricule'] ?? '',
      name: args['name'] ?? '',
      email: '', // Email not provided in login
      role: _getUserRoleFromType(args['type'] ?? ''),
      createdAt: DateTime.now(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${user.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: _buildDashboardForRole(user),
    );
  }

  UserRole _getUserRoleFromType(String type) {
    switch (type) {
      case 'operator':
        return UserRole.operator;
      case 'technician':
        return UserRole.maintenanceService;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.operator;
    }
  }

  Widget _buildDashboardForRole(User user) {
    switch (user.role) {
      case UserRole.operator:
        return OperatorDashboard(user: user);
      case UserRole.qualityAgent:
        return QualityAgentDashboard(user: user);
      case UserRole.maintenanceService:
        return MaintenanceDashboard(user: user);
      case UserRole.admin:
        return AdminDashboard(user: user);
    }
  }
}
