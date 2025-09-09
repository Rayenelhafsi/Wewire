import 'package:flutter/material.dart';
import '../../models/operator_model.dart';
import '../../models/technician_model.dart';
import '../../models/user_model.dart';
import '../../services/firebase_service.dart';
import '../../services/session_service.dart';

class MatriculeLoginScreen extends StatefulWidget {
  const MatriculeLoginScreen({super.key});

  @override
  State<MatriculeLoginScreen> createState() => _MatriculeLoginScreenState();
}

class _MatriculeLoginScreenState extends State<MatriculeLoginScreen> {
  final TextEditingController _matriculeController = TextEditingController();
  List<Operator> _operators = [];
  List<Technician> _technicians = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _loadUsers() async {
    try {
      // Get all operators and technicians from Firestore
      final operatorsStream = FirebaseService.getAllOperators();
      final techniciansStream = FirebaseService.getAllTechnicians();

      operatorsStream.listen((operators) {
        setState(() {
          _operators = operators;
        });
      });

      techniciansStream.listen((technicians) {
        setState(() {
          _technicians = technicians;
          _isLoading = false;
        });
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading users: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _matriculeController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final matricule = _matriculeController.text.trim();

    if (matricule.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your matricule')),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Try to authenticate as operator first
      User? user = await FirebaseService.authenticateOperator(matricule);

      if (user == null) {
        // If not operator, try to authenticate as technician
        user = await FirebaseService.authenticateTechnician(matricule);
      }

      // Dismiss loading indicator
      Navigator.of(context).pop();

      if (user != null) {
        // Save user session for operators/technicians
        await SessionService.saveUserSession(user);

        // Authentication successful
        Navigator.pushReplacementNamed(context, '/dashboard', arguments: user);
      } else {
        // Authentication failed
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid matricule. Please check your matricule.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Dismiss loading indicator
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during authentication: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 16, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadUsers, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

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
                Image.asset('assets/images/logo.png', width: 150, height: 200),
                const SizedBox(height: 5),
                const Text(
                  'Maintenance System',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                      ..._operators.map(
                        (op) => ListTile(
                          title: Text(op.matricule),
                          subtitle: Text('${op.name} - Operator'),
                          onTap: () => _matriculeController.text = op.matricule,
                        ),
                      ),
                      ..._technicians.map(
                        (tech) => ListTile(
                          title: Text(tech.matricule),
                          subtitle: Text('${tech.name} - Technician'),
                          onTap: () =>
                              _matriculeController.text = tech.matricule,
                        ),
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
