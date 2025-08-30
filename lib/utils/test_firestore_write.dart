import 'package:flutter/material.dart';
import '../models/machine_analytics_model.dart';
import '../services/firebase_service.dart';

class TestFirestoreWrite extends StatelessWidget {
  const TestFirestoreWrite({Key? key}) : super(key: key);

  Future<void> _testSave() async {
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

    await FirebaseService.saveMachineAnalytics(sampleAnalytics);
    print('Test saveMachineAnalytics completed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Firestore Write')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await _testSave();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Test data saved to Firestore')),
            );
          },
          child: const Text('Save Test Analytics Data'),
        ),
      ),
    );
  }
}
