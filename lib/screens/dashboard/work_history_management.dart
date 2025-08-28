import 'package:flutter/material.dart';
import '../../models/session_model.dart';
import '../../services/firebase_service.dart';
import '../../models/operator_model.dart';

class WorkHistoryManagement extends StatefulWidget {
  const WorkHistoryManagement({super.key});

  @override
  State<WorkHistoryManagement> createState() => _WorkHistoryManagementState();
}

class _WorkHistoryManagementState extends State<WorkHistoryManagement> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Work History',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Session>>(
              stream: FirebaseService.getSessionHistory(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final sessions = snapshot.data ?? [];

                if (sessions.isEmpty) {
                  return const Center(child: Text('No work history found'));
                }

                return ListView.builder(
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return FutureBuilder<Operator?>(
                      future: FirebaseService.getOperator(
                        session.operatorMatricule,
                      ),
                      builder: (context, operatorSnapshot) {
                        final operator = operatorSnapshot.data;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(operator?.name ?? 'Unknown Operator'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Machine: ${session.machineReference}'),
                                Text(
                                  'Start Time: ${_formatDateTime(session.startTime)}',
                                ),
                                if (session.endTime != null)
                                  Text(
                                    'End Time: ${_formatDateTime(session.endTime!)}',
                                  ),
                                Text('Status: ${session.status.name}'),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
