import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../models/technician_model.dart';

class TechnicianForm extends StatefulWidget {
  final Technician? technician;

  const TechnicianForm({super.key, this.technician});

  @override
  State<TechnicianForm> createState() => _TechnicianFormState();
}

class _TechnicianFormState extends State<TechnicianForm> {
  final _formKey = GlobalKey<FormState>();
  final _matriculeController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isAvailable = true;

  @override
  void initState() {
    super.initState();
    if (widget.technician != null) {
      _matriculeController.text = widget.technician!.matricule;
      _nameController.text = widget.technician!.name;
      _isAvailable = widget.technician!.isAvailable;
    }
  }

  @override
  void dispose() {
    _matriculeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.technician == null ? 'Add Technician' : 'Edit Technician'),
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
              SwitchListTile(
                title: const Text('Available'),
                value: _isAvailable,
                onChanged: (value) {
                  setState(() {
                    _isAvailable = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveTechnician,
                child: const Text('Save Technician'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveTechnician() async {
    if (_formKey.currentState!.validate()) {
      try {
        final technician = Technician(
          matricule: _matriculeController.text,
          name: _nameController.text,
          specializations: [], // Empty list since we removed specializations
          isAvailable: _isAvailable,
          workStartTime: widget.technician?.workStartTime,
          workEndTime: widget.technician?.workEndTime,
          assignedIssues: widget.technician?.assignedIssues ?? [],
        );

        await FirebaseService.saveTechnician(technician);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Technician saved successfully')),
        );
        
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving technician: $e')),
        );
      }
    }
  }
}
