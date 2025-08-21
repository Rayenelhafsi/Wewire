class Issue {
  final String id;
  final String machineId;
  final String reporterId;
  final String title;
  final String description;
  final IssuePriority priority;
  final IssueStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? assignedMaintenanceId;
  final List<String> tags;

  Issue({
    required this.id,
    required this.machineId,
    required this.reporterId,
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
    this.assignedMaintenanceId,
    this.tags = const [],
  });

  factory Issue.fromJson(Map<String, dynamic> json) => Issue(
        id: json['id'] ?? '',
        machineId: json['machineId'] ?? '',
        reporterId: json['reporterId'] ?? '',
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        priority: IssuePriority.values.firstWhere((e) => e.toString() == 'IssuePriority.${json['priority']}'),
        status: IssueStatus.values.firstWhere((e) => e.toString() == 'IssueStatus.${json['status']}'),
        createdAt: DateTime.parse(json['createdAt']),
        resolvedAt: json['resolvedAt'] != null ? DateTime.parse(json['resolvedAt']) : null,
        assignedMaintenanceId: json['assignedMaintenanceId'],
        tags: List<String>.from(json['tags'] ?? []),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'machineId': machineId,
        'reporterId': reporterId,
        'title': title,
        'description': description,
        'priority': priority.name,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'resolvedAt': resolvedAt?.toIso8601String(),
        'assignedMaintenanceId': assignedMaintenanceId,
        'tags': tags,
      };

  Issue copyWith({
    String? id,
    String? machineId,
    String? reporterId,
    String? title,
    String? description,
    IssuePriority? priority,
    IssueStatus? status,
    DateTime? createdAt,
    DateTime? resolvedAt,
    String? assignedMaintenanceId,
    List<String>? tags,
  }) {
    return Issue(
      id: id ?? this.id,
      machineId: machineId ?? this.machineId,
      reporterId: reporterId ?? this.reporterId,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      assignedMaintenanceId: assignedMaintenanceId ?? this.assignedMaintenanceId,
      tags: tags ?? this.tags,
    );
  }
}

enum IssuePriority {
  low,
  medium,
  high,
  critical,
}

enum IssueStatus {
  reported,
  acknowledged,
  inProgress,
  resolved,
  closed,
}
