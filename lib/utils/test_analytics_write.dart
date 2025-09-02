import 'package:flutter/material.dart';
import '../models/machine_analytics_model.dart';
import '../services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('Testing Firestore analytics write...');

  final sampleAnalytics = MachineAnalytics(
    machineId: 'TEST001',
    dailyStoppedTime: {'2023-01-01': Duration(seconds: 120)},
    monthlyStoppedTime: {'2023-01': Duration(seconds: 120)},
    yearlyStoppedTime: {'2023': Duration(seconds: 120)},
    totalWorkingTime: Duration(seconds: 3600),
    totalStoppedTime: Duration(seconds: 120),
    stoppedWithoutMaintenanceTime: Duration(seconds: 30),
    stoppedReadyForWorkTime: Duration(seconds: 20),
    maintenanceInProgressTime: Duration(seconds: 10),
    lastUpdated: DateTime.now(),
  );

  try {
    await FirebaseService.saveMachineAnalytics(sampleAnalytics);
    debugPrint('✓ Test saveMachineAnalytics completed successfully');
  } catch (e) {
    debugPrint('✗ Error saving analytics: $e');
  }
}
