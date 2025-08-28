import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import intl package
import '../../models/user_model.dart' as app_models;
import '../../models/machine_model.dart';
import '../../models/issue_model.dart';
import '../../models/private_chat_model.dart';
import '../../models/session_model.dart';
import '../../services/firebase_service.dart';
import '../../screens/chat/chat_screen.dart';

class OperatorDashboard extends StatefulWidget {
  final app_models.User user;

  const OperatorDashboard({super.key, required this.user});

  @override
  State<OperatorDashboard> createState() => _OperatorDashboardState();
}

class _OperatorDashboardState extends State<OperatorDashboard> {
  String? _currentlyWorkingMachineId;
  String? _currentSessionId;

  void _startWork(Machine machine) {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Work'),
        content: Text(
          'Are you sure you want to start working on ${machine.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Start work on the machine
              await _startWorkOnMachine(machine);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _startWorkOnMachine(Machine machine) async {
    try {
      // Create a new session
      final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      final newSession = Session(
        id: sessionId,
        operatorMatricule: widget.user.id, // Assuming user.id is the matricule
        technicianMatricule: '', // Not assigned yet
        machineReference: machine.id,
        issueTitle: 'Work on ${machine.name}',
        issueDescription:
            'Operator ${widget.user.name} started working on ${machine.name}',
        startTime: DateTime.now(),
        status: SessionStatus.inProgress, // In progress status for active work
      );

      // Save the session to Firestore
      await FirebaseService.createSession(newSession);

      // Update state
      setState(() {
        _currentlyWorkingMachineId = machine.id;
        _currentSessionId = sessionId;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Started working on ${machine.name}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to start work: $e')));
    }
  }

  void _stopWork() {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Work'),
        content: const Text('Are you sure you want to stop working?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Stop work
              await _stopWorkOnMachine();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _stopWorkOnMachine() async {
    try {
      if (_currentSessionId != null) {
        // Get the current session
        // For simplicity, we'll create a new session object with the end time
        // In a real app, you might want to fetch the existing session from Firestore
        final updatedSession = Session(
          id: _currentSessionId!,
          operatorMatricule: widget.user.id,
          technicianMatricule: '',
          machineReference: _currentlyWorkingMachineId ?? '',
          issueTitle: 'Work on machine',
          issueDescription: 'Operator ${widget.user.name} worked on machine',
          startTime: DateTime.now().subtract(
            const Duration(hours: 1),
          ), // Placeholder
          endTime: DateTime.now(),
          status: SessionStatus.closed,
        );

        // Update the session in Firestore
        await FirebaseService.updateSession(updatedSession);

        // Update state
        setState(() {
          _currentlyWorkingMachineId = null;
          _currentSessionId = null;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Stopped working')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to stop work: $e')));
    }
  }

  void _reportIssue(Machine machine) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    IssuePriority? selectedPriority;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Issue'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Machine: ${machine.name}'),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Issue Title*',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description*',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<IssuePriority>(
                value: selectedPriority,
                decoration: const InputDecoration(
                  labelText: 'Priority Level*',
                  border: OutlineInputBorder(),
                ),
                items: IssuePriority.values.map((priority) {
                  return DropdownMenuItem<IssuePriority>(
                    value: priority,
                    child: Text(priority.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (priority) {
                  selectedPriority = priority;
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a priority level';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Validate required fields
              if (titleController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter an issue title')),
                );
                return;
              }

              if (descriptionController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a description')),
                );
                return;
              }

              if (selectedPriority == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select a priority level'),
                  ),
                );
                return;
              }

              final newIssue = Issue(
                id: 'issue_${DateTime.now().millisecondsSinceEpoch}',
                machineId: machine.id,
                reporterId: widget.user.id,
                title: titleController.text,
                description: descriptionController.text,
                priority: selectedPriority!,
                status: IssueStatus.reported,
                createdAt: DateTime.now(),
              );

              // Save to Firestore
              try {
                await FirebaseService.saveIssue(newIssue);

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Issue reported successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to report issue: $e')),
                );
              }
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Machines',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Machine>>(
              stream: FirebaseService.getMachinesByAssignedOperator(
                widget.user.id,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final machines = snapshot.data ?? [];

                if (machines.isEmpty) {
                  return const Center(
                    child: Text('No machines assigned to you'),
                  );
                }

                return ListView.builder(
                  itemCount: machines.length,
                  itemBuilder: (context, index) {
                    final machine = machines[index];
                    final isCurrentlyWorkingOnThisMachine =
                        _currentlyWorkingMachineId == machine.id;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(machine.status),
                          child: const Icon(Icons.build, color: Colors.white),
                        ),
                        title: Text(machine.name),
                        subtitle: Text(
                          '${machine.model} - ${machine.location}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isCurrentlyWorkingOnThisMachine)
                              ElevatedButton(
                                onPressed: _stopWork,
                                child: const Text('Stop Working'),
                              )
                            else
                              ElevatedButton(
                                onPressed: () => _startWork(machine),
                                child: const Text('Start Working'),
                              ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _reportIssue(machine),
                              child: const Text('Report Issue'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Reported Issues',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Issue>>(
              stream: FirebaseService.getAllIssues(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allIssues = snapshot.data ?? [];
                final reportedIssues = allIssues
                    .where((issue) => issue.reporterId == widget.user.id)
                    .toList();

                if (reportedIssues.isEmpty) {
                  return const Center(child: Text('No issues reported yet'));
                }

                return ListView.builder(
                  itemCount: reportedIssues.length,
                  itemBuilder: (context, index) {
                    final issue = reportedIssues[index];
                    return Card(
                      child: ListTile(
                        title: Text(issue.title),
                        subtitle: Text('Status: ${issue.status.name}'),
                        trailing: Chip(
                          label: Text(issue.priority.name.toUpperCase()),
                          backgroundColor: _getPriorityColor(issue.priority),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'My Chats',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<PrivateChat>>(
              stream: FirebaseService.getUserPrivateChats(widget.user.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final chats = snapshot.data ?? [];

                if (chats.isEmpty) {
                  return const Center(child: Text('No chats available'));
                }

                return ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          chat.participant1Name == widget.user.name
                              ? chat.participant2Name
                              : chat.participant1Name,
                        ),
                        subtitle: Text(
                          'Last message at: ${DateFormat.yMMMd().add_jm().format(chat.lastMessageAt.toDate())}',
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  chatId: chat.id,
                                  isPrivateChat: true,
                                  title:
                                      chat.participant1Name == widget.user.name
                                      ? chat.participant2Name
                                      : chat.participant1Name,
                                  user: widget.user,
                                ),
                              ),
                            );
                          },
                          child: const Text('Open Chat'),
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

  Color _getStatusColor(MachineStatus status) {
    switch (status) {
      case MachineStatus.operational:
        return Colors.green;
      case MachineStatus.needsAttention:
        return Colors.orange;
      case MachineStatus.underMaintenance:
        return Colors.blue;
      case MachineStatus.broken:
        return Colors.red;
    }
  }

  Color _getPriorityColor(IssuePriority priority) {
    switch (priority) {
      case IssuePriority.low:
        return Colors.green.shade100;
      case IssuePriority.medium:
        return Colors.orange.shade100;
      case IssuePriority.high:
        return Colors.red.shade100;
      case IssuePriority.critical:
        return Colors.red.shade300;
    }
  }
}
