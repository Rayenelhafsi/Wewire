import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Add this line
import '../../models/session_model.dart';
import '../../services/firebase_service.dart';
import '../../models/operator_model.dart';
import '../../models/machine_model.dart';

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
          ElevatedButton(
            onPressed: _addNewWorkHistory,
            child: const Text('Add New Work History'),
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
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _editWorkHistory(session),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () =>
                                      _deleteWorkHistory(session.id),
                                ),
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

  void _addNewWorkHistory() {
    // Logic to show a form for adding new work history
    showDialog(
      context: context,
      builder: (context) {
        final operatorController = TextEditingController();
        final machineController = TextEditingController();
        final startTimeController = TextEditingController();
        final endTimeController = TextEditingController();
        final statusController = TextEditingController(text: 'inProgress');
        return AlertDialog(
          title: const Text('Add New Work History'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FutureBuilder<List<Operator>>(
                future: FirebaseService.getAllOperators().first,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  final operators = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    value: operatorController.text.isNotEmpty
                        ? operatorController.text
                        : (operators.isNotEmpty
                              ? operators.first.matricule
                              : null),
                    decoration: const InputDecoration(labelText: 'Operator'),
                    items: operators.map((operator) {
                      return DropdownMenuItem<String>(
                        value: operator.matricule,
                        child: Text(operator.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        operatorController.text = value;
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select an operator';
                      }
                      return null;
                    },
                  );
                },
              ),
              FutureBuilder<List<Machine>>(
                future: FirebaseService.getMachines().first,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  final machines = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    value: machineController.text.isNotEmpty
                        ? machineController.text
                        : (machines.isNotEmpty ? machines.first.id : null),
                    decoration: const InputDecoration(labelText: 'Machine'),
                    items: machines.map((machine) {
                      return DropdownMenuItem<String>(
                        value: machine.id,
                        child: Text(machine.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        machineController.text = value;
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a machine';
                      }
                      return null;
                    },
                  );
                },
              ),
              TextField(
                controller: startTimeController,
                decoration: const InputDecoration(labelText: 'Start Time'),
              ),
              TextField(
                controller: endTimeController,
                decoration: const InputDecoration(
                  labelText: 'End Time (if ended)',
                ),
              ),
              DropdownButtonFormField<String>(
                value: statusController.text,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(
                    value: 'inProgress',
                    child: Text('In Progress'),
                  ),
                  DropdownMenuItem(value: 'closed', child: Text('Stopped')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    statusController.text = value;
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Logic to save the new work history
                if (operatorController.text.isEmpty ||
                    machineController.text.isEmpty ||
                    startTimeController.text.isEmpty) {
                  // Show an error message if any required field is empty
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields'),
                    ),
                  );
                  return;
                }

                try {
                  final newSession = Session(
                    id: 'session_${DateTime.now().millisecondsSinceEpoch}',
                    operatorMatricule: operatorController.text,
                    technicianMatricule:
                        'technician_matricule', // Replace with actual technician matricule
                    machineReference: machineController.text,
                    issueTitle: 'Work History Entry', // Placeholder
                    issueDescription:
                        'Description of work history', // Placeholder
                    startTime: DateFormat(
                      'dd/MM/yyyy HH:mm',
                    ).parseStrict(startTimeController.text),
                    endTime: endTimeController.text.isNotEmpty
                        ? DateFormat(
                            'dd/MM/yyyy HH:mm',
                          ).parseStrict(endTimeController.text)
                        : null,
                    status: statusController.text == 'inProgress'
                        ? SessionStatus.inProgress
                        : SessionStatus.closed,
                  );
                  await FirebaseService.createSession(newSession);
                  Navigator.pop(context);
                } catch (e) {
                  // Show an error message if date parsing fails
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Invalid date format. Please check your input.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _editWorkHistory(Session session) {
    // Logic to show a form for editing the selected work history
    showDialog(
      context: context,
      builder: (context) {
        final operatorController = TextEditingController(
          text: session.operatorMatricule,
        );
        final machineController = TextEditingController(
          text: session.machineReference,
        );
        final startTimeController = TextEditingController(
          text: _formatDateTime(session.startTime),
        );
        final endTimeController = TextEditingController(
          text: session.endTime != null
              ? _formatDateTime(session.endTime!)
              : '',
        );
        final statusController = TextEditingController(
          text: session.status.name == 'closed'
              ? 'stopped'
              : session.status.name,
        );
        return AlertDialog(
          title: const Text('Edit Work History'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FutureBuilder<List<Operator>>(
                future: FirebaseService.getAllOperators().first,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  final operators = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    value: operatorController.text.isNotEmpty
                        ? operatorController.text
                        : (operators.isNotEmpty
                              ? operators
                                    .firstWhere(
                                      (op) =>
                                          op.matricule ==
                                          session.operatorMatricule,
                                      orElse: () => operators.first,
                                    )
                                    .matricule
                              : null),
                    decoration: const InputDecoration(labelText: 'Operator'),
                    items: operators.map((operator) {
                      return DropdownMenuItem<String>(
                        value: operator.matricule,
                        child: Text(operator.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        operatorController.text = value;
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select an operator';
                      }
                      return null;
                    },
                  );
                },
              ),
              FutureBuilder<List<Machine>>(
                future: FirebaseService.getMachines().first,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  final machines = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    value: machineController.text.isNotEmpty
                        ? machineController.text
                        : (machines.isNotEmpty
                              ? machines
                                    .firstWhere(
                                      (m) => m.id == session.machineReference,
                                      orElse: () => machines.first,
                                    )
                                    .id
                              : null),
                    decoration: const InputDecoration(labelText: 'Machine'),
                    items: machines.map((machine) {
                      return DropdownMenuItem<String>(
                        value: machine.id,
                        child: Text(machine.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        machineController.text = value;
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a machine';
                      }
                      return null;
                    },
                  );
                },
              ),
              TextField(
                controller: startTimeController,
                decoration: const InputDecoration(labelText: 'Start Time'),
              ),
              TextField(
                controller: endTimeController,
                decoration: const InputDecoration(
                  labelText: 'End Time (if ended)',
                ),
              ),
              DropdownButtonFormField<String>(
                value: statusController.text,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'stopped', child: Text('Stopped')),
                  DropdownMenuItem(
                    value: 'inProgress',
                    child: Text('In Progress'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    statusController.text = value;
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Logic to update the work history
                final updatedSession = Session(
                  id: session.id,
                  operatorMatricule: operatorController.text,
                  technicianMatricule: session.technicianMatricule,
                  machineReference: machineController.text,
                  issueTitle: session.issueTitle,
                  issueDescription: session.issueDescription,
                  startTime: DateFormat(
                    'dd/MM/yyyy HH:mm',
                  ).parseStrict(startTimeController.text),
                  endTime: endTimeController.text.isNotEmpty
                      ? DateFormat(
                          'dd/MM/yyyy HH:mm',
                        ).parseStrict(endTimeController.text)
                      : null,
                  status: statusController.text == 'inProgress'
                      ? SessionStatus.inProgress
                      : SessionStatus.closed,
                );
                await FirebaseService.updateSession(updatedSession);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteWorkHistory(String sessionId) {
    // Logic to delete the selected work history
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Work History'),
        content: const Text(
          'Are you sure you want to delete this work history entry?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Logic to delete the work history
              await FirebaseService.deleteSession(sessionId);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
