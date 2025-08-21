class Machine {
  final String id;
  final String name;
  final String model;
  final String location;
  final MachineStatus status;
  final DateTime lastMaintenance;
  final String? assignedOperatorId;

  Machine({
    required this.id,
    required this.name,
    required this.model,
    required this.location,
    required this.status,
    required this.lastMaintenance,
    this.assignedOperatorId,
  });

  factory Machine.fromJson(Map<String, dynamic> json) => Machine(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        model: json['model'] ?? '',
        location: json['location'] ?? '',
        status: MachineStatus.values.firstWhere((e) => e.toString() == 'MachineStatus.${json['status']}'),
        lastMaintenance: DateTime.parse(json['lastMaintenance']),
        assignedOperatorId: json['assignedOperatorId'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'model': model,
        'location': location,
        'status': status.name,
        'lastMaintenance': lastMaintenance.toIso8601String(),
        'assignedOperatorId': assignedOperatorId,
      };
}

enum MachineStatus {
  operational,
  needsAttention,
  underMaintenance,
  broken,
}
