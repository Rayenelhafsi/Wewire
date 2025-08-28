import 'package:flutter/material.dart';
import '../../models/session_model.dart';
import '../../services/firebase_service.dart';

class WorkRequestsManagement extends StatefulWidget {
  const WorkRequestsManagement({super.key});

  @override
  State<WorkRequestsManagement> createState() => _WorkRequestsManagementState();
}

class _WorkRequestsManagementState extends State<WorkRequestsManagement> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Work Requests Management',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Session>>(
              stream: FirebaseService.getActiveSessions(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final sessions = snapshot.data ?? [];

                if (sessions.isEmpty) {
                  return const Center(child: Text('No work requests found'));
                }

                return ListView.builder(
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(session.issueTitle),
                        subtitle: Text(
                          'Requested by: ${session.operatorMatricule}',
                        ),
                        trailing: ElevatedButton(
                          onPressed: session.status == SessionStatus.open
                              ? () async {
                                  try {
                                    // Update the session status to inProgress
                                    await FirebaseService.updateSession(
                                      Session(
                                        id: session.id,
                                        operatorMatricule:
                                            session.operatorMatricule,
                                        technicianMatricule:
                                            session.technicianMatricule,
                                        machineReference:
                                            session.machineReference,
                                        issueTitle: session.issueTitle,
                                        issueDescription:
                                            session.issueDescription,
                                        startTime: session.startTime,
                                        endTime: session.endTime,
                                        status: SessionStatus.inProgress,
                                      ),
                                    );

                                    // Notify the operator to start work
                                    await FirebaseService.sendNotificationToOperator(
                                      session.operatorMatricule,
                                      'Work Request Confirmed',
                                      'Your work request for ${session.issueTitle} has been confirmed. Please start working.',
                                    );

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Work request confirmed and operator notified',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error confirming work request: $e',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              : null,
                          child: Text(
                            session.status == SessionStatus.open
                                ? 'Confirm'
                                : 'Confirmed',
                          ),
                        ),
                      ),
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
}
