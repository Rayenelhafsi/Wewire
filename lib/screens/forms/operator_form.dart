import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../models/operator_model.dart';

class OperatorForm extends StatefulWidget {
  final Operator? operator;

  const OperatorForm({super.key, this.operator});

  @override
  State<OperatorForm> createState() => _OperatorFormState();
}

class _OperatorFormState extends State<OperatorForm> {
  final _formKey = GlobalKey<FormState>();
  final _matriculeController = TextEditingController();
  final _nameController = TextEditingController();
  final _savedPhrasesController = TextEditingController();
  final _assignedMachinesController = TextEditingController();
  bool _isCurrentlyWorking = false;

  @override
  void initState() {
    super.initState();
    if (widget.operator != null) {
      _matriculeController.text = widget.operator!.matricule;
      _nameController.text = widget.operator!.name;
      _savedPhrasesController.text = widget.operator!.savedPhrases.join(', ');
      _assignedMachinesController.text = widget.operator!.assignedMachines.join(', ');
      _isCurrentlyWorking = widget.operator!.isCurrentlyWorking;
    }
  }

  @override
  void dispose() {
    _matriculeController.dispose();
    _nameController.dispose();
    _savedPhrasesController.dispose();
    _assignedMachinesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.operator == null ? 'Add Operator' : 'Edit Operator'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _matriculeController,
                decoration: const InputDecoration(
                  labelText: 'Matricule',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a matricule';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _savedPhrasesController,
                decoration: const InputDecoration(
                  labelText: 'Saved Phrases (comma separated)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _assignedMachinesController,
                decoration: const InputDecoration(
                  labelText: 'Assigned Machines (comma separated)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Currently Working'),
                value: _isCurrentlyWorking,
                onChanged: (value) {
                  setState(() {
                    _isCurrentlyWorking = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveOperator,
                child: const Text('Save Operator'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveOperator() async {
    if (_formKey.currentState!.validate()) {
      try {
        final operator = Operator(
          matricule: _matriculeController.text,
          name: _nameController.text,
          savedPhrases: _savedPhrasesController.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
          assignedMachines: _assignedMachinesController.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
          workStartTime: widget.operator?.workStartTime,
          workEndTime: widget.operator?.workEndTime,
          isCurrentlyWorking: _isCurrentlyWorking,
        );

        await FirebaseService.saveOperator(operator);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Operator saved successfully')),
        );
        
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving operator: $e')),
        );
      }
    }
  }
}
