import 'package:flutter/material.dart';
import '../../models/user_model.dart' as app_models;
import '../../services/firebase_service.dart';
import '../../models/technician_model.dart';
import '../../models/operator_model.dart';
import '../../models/machine_model.dart';
import '../../models/issue_model.dart';
import '../../models/private_chat_model.dart';
import '../../screens/forms/technician_form.dart';
import '../../screens/forms/operator_form.dart';
import '../../screens/forms/machine_form.dart';
import '../../screens/chat/chat_screen.dart';
import '../../screens/dashboard/work_requests_management.dart';
import '../../screens/dashboard/work_history_management.dart';
import '../../screens/dashboard/analytics_dashboard.dart';

class AdminDashboard extends StatefulWidget {
  final app_models.User user;

  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  List<Widget> _widgetOptions = [];

  @override
  void initState() {
    super.initState();
    _widgetOptions = [
      TechniciansManagement(user: widget.user),
      OperatorsManagement(),
      MachinesManagement(),
      IssuesManagement(),
      WorkRequestsManagement(), // New section for work requests
      WorkHistoryManagement(), // New section for work history
      AnalyticsDashboard(), // Analytics dashboard
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.engineering),
            label: 'Technicians',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Operators'),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Machines'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Issues'),
          BottomNavigationBarItem(
            icon: Icon(Icons.work),
            label: 'Work Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Work History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}

class IssuesManagement extends StatefulWidget {
  const IssuesManagement({super.key});

  @override
  State<IssuesManagement> createState() => _IssuesManagementState();
}

class _IssuesManagementState extends State<IssuesManagement> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Issues Management',
            style: Theme.of(context).textTheme.headlineSmall,
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

                final issues = snapshot.data ?? [];

                if (issues.isEmpty) {
                  return const Center(child: Text('No issues found'));
                }

                return ListView.builder(
                  itemCount: issues.length,
                  itemBuilder: (context, index) {
                    final issue = issues[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          _getStatusIcon(issue.status),
                          color: _getStatusColor(issue.status),
                        ),
                        title: Text(issue.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID: ${issue.id}'),
                            Text('Status: ${issue.status.name}'),
                            Text('Created: ${_formatDate(issue.createdAt)}'),
                            if (issue.description.isNotEmpty)
                              Text('Description: ${issue.description}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.engineering, size: 20),
                              onPressed: () {
                                _showAssignTechnicianDialog(issue);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () {
                                _showStatusUpdateDialog(issue);
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                size: 20,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                _deleteIssue(issue.id);
                              },
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
        ],
      ),
    );
  }

  IconData _getStatusIcon(IssueStatus status) {
    switch (status) {
      case IssueStatus.reported:
        return Icons.error_outline;
      case IssueStatus.acknowledged:
        return Icons.info_outline;
      case IssueStatus.inProgress:
        return Icons.build;
      case IssueStatus.resolved:
        return Icons.check_circle;
      case IssueStatus.closed:
        return Icons.archive;
    }
  }

  Color _getStatusColor(IssueStatus status) {
    switch (status) {
      case IssueStatus.reported:
        return Colors.orange;
      case IssueStatus.acknowledged:
        return Colors.blue;
      case IssueStatus.inProgress:
        return Colors.blue;
      case IssueStatus.resolved:
        return Colors.green;
      case IssueStatus.closed:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showStatusUpdateDialog(Issue issue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Issue Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: IssueStatus.values.map((status) {
            return ListTile(
              leading: Icon(
                _getStatusIcon(status),
                color: _getStatusColor(status),
              ),
              title: Text(status.name),
              onTap: () {
                Navigator.pop(context);
                _updateIssueStatus(issue, status);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _updateIssueStatus(Issue issue, IssueStatus newStatus) {
    final updatedIssue = issue.copyWith(status: newStatus);
    FirebaseService.updateIssue(updatedIssue)
        .then((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Issue status updated successfully')),
          );
        })
        .catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating issue: $error')),
          );
        });
  }

  void _showAssignTechnicianDialog(Issue issue) {
    Technician? selectedTechnician;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Technician'),
        content: StreamBuilder<List<Technician>>(
          stream: FirebaseService.getAllTechnicians(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            final technicians = snapshot.data ?? [];

            if (technicians.isEmpty) {
              return const Text('No technicians available');
            }

            return DropdownButtonFormField<Technician>(
              value: selectedTechnician,
              decoration: const InputDecoration(
                labelText: 'Select Technician',
                border: OutlineInputBorder(),
              ),
              items: technicians.map((technician) {
                return DropdownMenuItem<Technician>(
                  value: technician,
                  child: Text('${technician.name} (${technician.matricule})'),
                );
              }).toList(),
              onChanged: (technician) {
                selectedTechnician = technician;
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select a technician';
                }
                return null;
              },
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (selectedTechnician == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a technician')),
                );
                return;
              }

              final updatedIssue = issue.copyWith(
                assignedMaintenanceId: selectedTechnician!.matricule,
                status: IssueStatus.acknowledged,
              );

              try {
                await FirebaseService.updateIssue(updatedIssue);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Technician ${selectedTechnician!.name} assigned successfully',
                    ),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error assigning technician: $e')),
                );
              }
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  void _deleteIssue(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Issue'),
        content: const Text('Are you sure you want to delete this issue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseService.deleteIssue(id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Issue deleted successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting issue: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class TechniciansManagement extends StatefulWidget {
  final app_models.User user;

  const TechniciansManagement({super.key, required this.user});

  @override
  State<TechniciansManagement> createState() => _TechniciansManagementState();
}

class _TechniciansManagementState extends State<TechniciansManagement> {
  late final app_models.User currentUser;

  @override
  void initState() {
    super.initState();
    currentUser = widget.user;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Technicians Management',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TechnicianForm()),
              );
            },
            child: const Text('Add New Technician'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Technician>>(
              stream: FirebaseService.getAllTechnicians(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final technicians = snapshot.data ?? [];

                if (technicians.isEmpty) {
                  return const Center(child: Text('No technicians found'));
                }

                return ListView.builder(
                  itemCount: technicians.length,
                  itemBuilder: (context, index) {
                    final technician = technicians[index];
                    return StreamBuilder<List<PrivateChat>>(
                      stream: FirebaseService.getUserPrivateChats(
                        currentUser.id,
                      ),
                      builder: (context, chatSnapshot) {
                        final unreadCount = _getUnreadCountForTechnician(
                          chatSnapshot.data ?? [],
                          technician.matricule,
                        );

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Stack(
                              children: [
                                const Icon(Icons.engineering),
                                if (unreadCount > 0)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 12,
                                        minHeight: 12,
                                      ),
                                      child: Text(
                                        unreadCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(technician.name),
                            subtitle: Text(
                              'Matricule: ${technician.matricule}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.chat,
                                    size: 20,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    _startChatWithTechnician(
                                      context,
                                      technician,
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => TechnicianForm(
                                          technician: technician,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    size: 20,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    _deleteTechnician(technician.matricule);
                                  },
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

  int _getUnreadCountForTechnician(
    List<PrivateChat> chats,
    String technicianId,
  ) {
    for (final chat in chats) {
      if (chat.participant2Id == technicianId ||
          chat.participant1Id == technicianId) {
        return chat.getUnreadCount(currentUser.id);
      }
    }
    return 0;
  }

  Future<void> _startChatWithTechnician(
    BuildContext context,
    Technician technician,
  ) async {
    try {
      // Check if chat already exists
      final existingChatId = await FirebaseService.findExistingPrivateChat(
        currentUser.id,
        technician.matricule,
      );

      String chatId;
      if (existingChatId != null) {
        chatId = existingChatId;
      } else {
        // Create new chat
        chatId = await FirebaseService.createPrivateChat(
          currentUser.id,
          currentUser.name,
          currentUser.role.name,
          technician.matricule,
          technician.name,
          'maintenance_service',
        );
      }

      // Navigate to chat screen using named route
      Navigator.pushNamed(
        context,
        '/chat',
        arguments: {
          'chatId': chatId,
          'isPrivateChat': true,
          'title': 'Chat with ${technician.name}',
          'user': currentUser,
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error starting chat: $e')));
    }
  }

  void _deleteTechnician(String matricule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Technician'),
        content: const Text('Are you sure you want to delete this technician?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseService.deleteTechnician(matricule);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Technician deleted successfully'),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting technician: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class OperatorsManagement extends StatefulWidget {
  const OperatorsManagement({super.key});

  @override
  State<OperatorsManagement> createState() => _OperatorsManagementState();
}

class _OperatorsManagementState extends State<OperatorsManagement> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operators Management',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OperatorForm()),
              );
            },
            child: const Text('Add New Operator'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Operator>>(
              stream: FirebaseService.getAllOperators(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final operators = snapshot.data ?? [];

                if (operators.isEmpty) {
                  return const Center(child: Text('No operators found'));
                }

                return ListView.builder(
                  itemCount: operators.length,
                  itemBuilder: (context, index) {
                    final operator = operators[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(operator.name),
                        subtitle: Text('Matricule: ${operator.matricule}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        OperatorForm(operator: operator),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                size: 20,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                _deleteOperator(operator.matricule);
                              },
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
        ],
      ),
    );
  }

  void _deleteOperator(String matricule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Operator'),
        content: const Text('Are you sure you want to delete this operator?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseService.deleteOperator(matricule);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Operator deleted successfully'),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting operator: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class MachinesManagement extends StatefulWidget {
  const MachinesManagement({super.key});

  @override
  State<MachinesManagement> createState() => _MachinesManagementState();
}

class _MachinesManagementState extends State<MachinesManagement> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Machines Management',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MachineForm()),
              );
            },
            child: const Text('Add New Machine'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Machine>>(
              stream: FirebaseService.getMachines(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final machines = snapshot.data ?? [];

                if (machines.isEmpty) {
                  return const Center(child: Text('No machines found'));
                }

                return ListView.builder(
                  itemCount: machines.length,
                  itemBuilder: (context, index) {
                    final machine = machines[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.build),
                        title: Text(machine.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID: ${machine.id}'),
                            Text('Model: ${machine.model}'),
                            Text('Status: ${machine.status.name}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        MachineForm(machine: machine),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                size: 20,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                _deleteMachine(machine.id);
                              },
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
        ],
      ),
    );
  }

  void _deleteMachine(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Machine'),
        content: const Text('Are you sure you want to delete this machine?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseService.deleteMachine(id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Machine deleted successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting machine: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
