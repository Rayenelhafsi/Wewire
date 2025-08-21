class Session {
  final String id;
  final String operatorMatricule;
  final String technicianMatricule;
  final String machineReference;
  final String issueTitle;
  final String issueDescription;
  final List<String> keywords;
  final DateTime startTime;
  final DateTime? endTime;
  final SessionStatus status;
  final InterventionType interventionType;
  final String resolutionNotes;
  final List<String> chatMessages;

  Session({
    required this.id,
    required this.operatorMatricule,
    required this.technicianMatricule,
    required this.machineReference,
    required this.issueTitle,
    required this.issueDescription,
    this.keywords = const [],
    required this.startTime,
    this.endTime,
    this.status = SessionStatus.open,
    this.interventionType = InterventionType.remote,
    this.resolutionNotes = '',
    this.chatMessages = const [],
  });

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        id: json['id'] ?? '',
        operatorMatricule: json['operatorMatricule'] ?? '',
        technicianMatricule: json['technicianMatricule'] ?? '',
        machineReference: json['machineReference'] ?? '',
        issueTitle: json['issueTitle'] ?? '',
        issueDescription: json['issueDescription'] ?? '',
        keywords: List<String>.from(json['keywords'] ?? []),
        startTime: DateTime.parse(json['startTime']),
        endTime: json['endTime'] != null 
            ? DateTime.parse(json['endTime']) 
            : null,
        status: SessionStatus.values.firstWhere(
          (e) => e.toString() == 'SessionStatus.${json['status']}',
        ),
        interventionType: InterventionType.values.firstWhere(
          (e) => e.toString() == 'InterventionType.${json['interventionType']}',
        ),
        resolutionNotes: json['resolutionNotes'] ?? '',
        chatMessages: List<String>.from(json['chatMessages'] ?? []),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'operatorMatricule': operatorMatricule,
        'technicianMatricule': technicianMatricule,
        'machineReference': machineReference,
        'issueTitle': issueTitle,
        'issueDescription': issueDescription,
        'keywords': keywords,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'status': status.name,
        'interventionType': interventionType.name,
        'resolutionNotes': resolutionNotes,
        'chatMessages': chatMessages,
      };
}

enum SessionStatus {
  open,
  inProgress,
  resolved,
  closed,
  delayed,
}

enum InterventionType {
  remote,
  inPerson,
}
