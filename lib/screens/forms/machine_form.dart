import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../models/machine_model.dart';

class MachineForm extends StatefulWidget {
  final Machine? machine;

  const MachineForm({super.key, this.machine});

  @override
  State<MachineForm> createState() => _MachineFormState();
}

class _MachineFormState extends State<MachineForm> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _modelController = TextEditingController();
  final _locationController = TextEditingController();
  final _assignedOperatorController = TextEditingController();
  MachineStatus _status = MachineStatus.operational;
  DateTime _lastMaintenance = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.machine != null) {
      _idController.text = widget.machine!.id;
      _nameController.text = widget.machine!.name;
      _modelController.text = widget.machine!.model;
      _locationController.text = widget.machine!.location;
      _status = widget.machine!.status;
      _lastMaintenance = widget.machine!.lastMaintenance;
      _assignedOperatorController.text = widget.machine!.assignedOperatorId ?? '';
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _modelController.dispose();
    _locationController.dispose();
    _assignedOperatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.machine == null ? 'Add Machine' : 'Edit Machine'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _idController,
                decoration: const InputDecoration(
                  labelText: 'Machine ID',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a machine ID';
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
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a model';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MachineStatus>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: MachineStatus.values.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(status.name),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _status = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _assignedOperatorController,
                decoration: const InputDecoration(
                  labelText: 'Assigned Operator ID (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Last Maintenance'),
                subtitle: Text(_lastMaintenance.toString()),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate: _lastMaintenance,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (selectedDate != null) {
                      setState(() {
                        _lastMaintenance = selectedDate;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveMachine,
                child: const Text('Save Machine'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveMachine() async {
    if (_formKey.currentState!.validate()) {
      try {
        final machine = Machine(
          id: _idController.text,
          name: _nameController.text,
          model: _modelController.text,
          location: _locationController.text,
          status: _status,
          lastMaintenance: _lastMaintenance,
          assignedOperatorId: _assignedOperatorController.text.isEmpty 
              ? null 
              : _assignedOperatorController.text,
        );

        await FirebaseService.saveMachine(machine);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Machine saved successfully')),
        );
        
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving machine: $e')),
        );
      }
    }
  }
}
