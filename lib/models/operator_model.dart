class Operator {
  final String matricule;
  final String name;
  final List<String> savedPhrases;
  final List<String> assignedMachines;
  final DateTime? workStartTime;
  final DateTime? workEndTime;
  final bool isCurrentlyWorking;
  final String? rfidTagUid;

  Operator({
    required this.matricule,
    required this.name,
    this.savedPhrases = const [],
    this.assignedMachines = const [],
    this.workStartTime,
    this.workEndTime,
    this.isCurrentlyWorking = false,
    this.rfidTagUid,
  });

  factory Operator.fromJson(Map<String, dynamic> json) => Operator(
    matricule: json['matricule'] ?? '',
    name: json['name'] ?? '',
    savedPhrases: List<String>.from(json['savedPhrases'] ?? []),
    assignedMachines: List<String>.from(json['assignedMachines'] ?? []),
    workStartTime: json['workStartTime'] != null
        ? DateTime.parse(json['workStartTime'])
        : null,
    workEndTime: json['workEndTime'] != null
        ? DateTime.parse(json['workEndTime'])
        : null,
    isCurrentlyWorking: json['isCurrentlyWorking'] ?? false,
    rfidTagUid: json['rfidTagUid'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'matricule': matricule,
    'name': name,
    'savedPhrases': savedPhrases,
    'assignedMachines': assignedMachines,
    'workStartTime': workStartTime?.toIso8601String(),
    'workEndTime': workEndTime?.toIso8601String(),
    'isCurrentlyWorking': isCurrentlyWorking,
    'rfidTagUid': rfidTagUid,
  };
}
