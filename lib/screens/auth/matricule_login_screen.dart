import 'package:flutter/material.dart';
import '../../models/operator_model.dart';
import '../../models/technician_model.dart';

class MatriculeLoginScreen extends StatefulWidget {
  const MatriculeLoginScreen({super.key});

  @override
  State<MatriculeLoginScreen> createState() => _MatriculeLoginScreenState();
}

class _MatriculeLoginScreenState extends State<MatriculeLoginScreen> {
  final TextEditingController _matriculeController = TextEditingController();
  final List<Operator> _operators = [
    Operator(matricule: 'OP001', name: 'Ahmed Benali'),
    Operator(matricule: 'OP002', name: 'Fatima Zahra'),
    Operator(matricule: 'OP003', name: 'Mohamed Amine'),
  ];
  
  final List<Technician> _technicians = [
    Technician(matricule: 'TECH001', name: 'Youssef El Amrani'),
    Technician(matricule: 'TECH002', name: 'Amina Belhaj'),
    Technician(matricule: 'TECH003', name: 'Khalid Bennis'),
  ];

  @override
  void dispose() {
    _matriculeController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    final matricule = _matriculeController.text.trim();
    
    if (matricule.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your matricule')),
      );
      return;
    }

    // Determine user type based on matricule
    String userType;
    String userName;
    
    if (matricule == 'ADMIN001') {
      userType = 'admin';
      userName = 'Administrator';
    } else if (_operators.any((op) => op.matricule == matricule)) {
      userType = 'operator';
      userName = _operators.firstWhere((op) => op.matricule == matricule).name;
    } else if (_technicians.any((tech) => tech.matricule == matricule)) {
      userType = 'technician';
      userName = _technicians.firstWhere((tech) => tech.matricule == matricule).name;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid matricule')),
      );
      return;
    }

    // Record work start time
    final workStartTime = DateTime.now();
    
    Navigator.pushReplacementNamed(
      context,
      '/dashboard',
      arguments: {
        'matricule': matricule,
        'name': userName,
        'type': userType,
        'workStartTime': workStartTime,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.build,
                  size: 80,
                  color: Colors.blue,
                ),
                const SizedBox(height: 32),
                const Text(
                  'Maintenance System',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                const Text(
                  'Enter your matricule:',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _matriculeController,
                  decoration: const InputDecoration(
                    labelText: 'Matricule',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: ListView(
                    children: [
                      ..._operators.map((op) => ListTile(
                        title: Text(op.matricule),
                        subtitle: Text('${op.name} - Operator'),
                        onTap: () => _matriculeController.text = op.matricule,
                      )),
                      ..._technicians.map((tech) => ListTile(
                        title: Text(tech.matricule),
                        subtitle: Text('${tech.name} - Technician'),
                        onTap: () => _matriculeController.text = tech.matricule,
                      )),
                      ListTile(
                        title: const Text('ADMIN001'),
                        subtitle: const Text('Administrator'),
                        onTap: () => _matriculeController.text = 'ADMIN001',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Start Work',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
