import 'package:flutter/material.dart';
import '../../models/session_model.dart';
import '../../services/firebase_service.dart';

class ProducedQuantityHistoryManagement extends StatefulWidget {
  const ProducedQuantityHistoryManagement({super.key});

  @override
  State<ProducedQuantityHistoryManagement> createState() =>
      _ProducedQuantityHistoryManagementState();
}

class _ProducedQuantityHistoryManagementState
    extends State<ProducedQuantityHistoryManagement> {
  DateTimeRange? _selectedDateRange;
  String? _selectedMachine;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Produced Quantity History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(now.year - 5),
                      lastDate: DateTime(now.year + 1),
                      initialDateRange: _selectedDateRange,
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDateRange = picked;
                      });
                    }
                  },
                  child: Text(
                    _selectedDateRange == null
                        ? 'Select Date Range'
                        : '${_selectedDateRange!.start.toLocal().toString().split(' ')[0]} - ${_selectedDateRange!.end.toLocal().toString().split(' ')[0]}',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StreamBuilder<List<String>>(
                    stream: FirebaseService.getMachineIds(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text('Error loading machines');
                      }
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }
                      final machines = snapshot.data!;
                      return DropdownButton<String?>(
                        isExpanded: true,
                        value: _selectedMachine,
                        hint: const Text('Select Machine or All'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Machines'),
                          ),
                          ...machines.map(
                            (machine) => DropdownMenuItem(
                              value: machine,
                              child: Text(machine),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedMachine = value;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Session>>(
              stream: FirebaseService.getFilteredSessions(
                dateRange: _selectedDateRange,
                machineId: _selectedMachine,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading sessions: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final sessions = snapshot.data!;
                if (sessions.isEmpty) {
                  return const Center(child: Text('No data found'));
                }
                return ListView.builder(
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return ListTile(
                      title: Text(
                        'Machine: ${session.machineReference ?? "N/A"}, Operator: ${session.operatorMatricule ?? "N/A"}',
                      ),
                      subtitle: Text(
                        'Produced Quantity: ${session.producedQuantity ?? 0}, Scrap Quantity: ${session.scrapQuantity ?? 0}',
                      ),
                      trailing: Text(
                        '${session.startTime != null ? session.startTime!.toLocal().toString().split(' ')[0] : "N/A"} - ${session.endTime != null ? session.endTime!.toLocal().toString().split(' ')[0] : "N/A"}',
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
