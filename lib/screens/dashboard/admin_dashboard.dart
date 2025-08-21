import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/firebase_service.dart';
import '../../models/technician_model.dart';
import '../../models/operator_model.dart';
import '../../models/machine_model.dart';
import '../../screens/forms/technician_form.dart';
import '../../screens/forms/operator_form.dart';
import '../../screens/forms/machine_form.dart';

class AdminDashboard extends StatefulWidget {
  final User user;

  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = [
    TechniciansManagement(),
    OperatorsManagement(),
    MachinesManagement(),
  ];

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
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Operators',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build),
            label: 'Machines',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}

class TechniciansManagement extends StatefulWidget {
  const TechniciansManagement({super.key});

  @override
  State<TechniciansManagement> createState() => _TechniciansManagementState();
}

class _TechniciansManagementState extends State<TechniciansManagement> {
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
                MaterialPageRoute(
                  builder: (context) => const TechnicianForm(),
                ),
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
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.engineering),
                        title: Text(technician.name),
                        subtitle: Text('Matricule: ${technician.matricule}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TechnicianForm(technician: technician),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
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
            ),
          ),
        ],
      ),
    );
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
                  const SnackBar(content: Text('Technician deleted successfully')),
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
                MaterialPageRoute(
                  builder: (context) => const OperatorForm(),
                ),
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
                                    builder: (context) => OperatorForm(operator: operator),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
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
                  const SnackBar(content: Text('Operator deleted successfully')),
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
                MaterialPageRoute(
                  builder: (context) => const MachineForm(),
                ),
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
                                    builder: (context) => MachineForm(machine: machine),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
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
