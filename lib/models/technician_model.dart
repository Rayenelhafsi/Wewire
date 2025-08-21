class Technician {
  final String matricule;
  final String name;
  final List<String> specializations;
  final bool isAvailable;
  final DateTime? workStartTime;
  final DateTime? workEndTime;
  final List<String> assignedIssues;

  Technician({
    required this.matricule,
    required this.name,
    this.specializations = const [],
    this.isAvailable = true,
    this.workStartTime,
    this.workEndTime,
    this.assignedIssues = const [],
  });

  factory Technician.fromJson(Map<String, dynamic> json) => Technician(
        matricule: json['matricule'] ?? '',
        name: json['name'] ?? '',
        isAvailable: json['isAvailable'] ?? true,
        workStartTime: json['workStartTime'] != null 
            ? DateTime.parse(json['workStartTime']) 
            : null,
        workEndTime: json['workEndTime'] != null 
            ? DateTime.parse(json['workEndTime']) 
            : null,
        assignedIssues: List<String>.from(json['assignedIssues'] ?? []),
      );

  Map<String, dynamic> toJson() => {
        'matricule': matricule,
        'name': name,
        'specializations': specializations,
        'isAvailable': isAvailable,
        'workStartTime': workStartTime?.toIso8601String(),
        'workEndTime': workEndTime?.toIso8601String(),
        'assignedIssues': assignedIssues,
      };
}
