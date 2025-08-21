import 'package:flutter/material.dart';
import '../../models/user_model.dart' as app_models;
import 'operator_dashboard.dart';
import 'quality_agent_dashboard.dart';
import 'maintenance_dashboard.dart';
import 'admin_dashboard.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = ModalRoute.of(context)?.settings.arguments as app_models.User?;
    
    if (user == null) {
      // Handle the case where user is null (e.g., redirect to login)
      return const Scaffold(
        body: Center(child: Text('No user data found. Please login again.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${user.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: _buildDashboardForRole(user),
    );
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
