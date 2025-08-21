import 'package:flutter/material.dart';
import '../../models/user_model.dart' as app_models;
import '../../models/issue_model.dart';

class MaintenanceDashboard extends StatefulWidget {
  final app_models.User user;

  const MaintenanceDashboard({super.key, required this.user});

  @override
  State<MaintenanceDashboard> createState() => _MaintenanceDashboardState();
}

class _MaintenanceDashboardState extends State<MaintenanceDashboard> {
  final List<Issue> _assignedIssues = [];
  late final List<Issue> _allIssues;

  @override
  void initState() {
    super.initState();
    _allIssues = [
      Issue(
        id: 'issue_1',
        machineId: '1',
        reporterId: 'operator_1',
        title: 'Temperature sensor malfunction',
        description: 'Temperature readings are inconsistent',
        priority: IssuePriority.high,
        status: IssueStatus.reported,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Issue(
        id: 'issue_2',
        machineId: '2',
        reporterId: 'operator_2',
        title: 'Vibration detected',
        description: 'Unusual vibration in the main spindle',
        priority: IssuePriority.medium,
        status: IssueStatus.acknowledged,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      Issue(
        id: 'issue_3',
        machineId: '3',
        reporterId: 'operator_3',
        title: 'Hydraulic pressure low',
        description: 'Hydraulic system pressure below threshold',
        priority: IssuePriority.critical,
        status: IssueStatus.inProgress,
        assignedMaintenanceId: widget.user.id,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ];
  }

  void _assignIssue(Issue issue) {
    setState(() {
      final index = _allIssues.indexWhere((i) => i.id == issue.id);
      if (index != -1) {
        _allIssues[index] = Issue(
          id: issue.id,
          machineId: issue.machineId,
          reporterId: issue.reporterId,
          title: issue.title,
          description: issue.description,
          priority: issue.priority,
          status: IssueStatus.inProgress,
          createdAt: issue.createdAt,
          assignedMaintenanceId: widget.user.id,
        );
        _assignedIssues.add(_allIssues[index]);
      }
    });
  }

  void _resolveIssue(Issue issue) {
    setState(() {
      final index = _allIssues.indexWhere((i) => i.id == issue.id);
      if (index != -1) {
        _allIssues[index] = Issue(
          id: issue.id,
          machineId: issue.machineId,
          reporterId: issue.reporterId,
          title: issue.title,
          description: issue.description,
          priority: issue.priority,
          status: IssueStatus.resolved,
          createdAt: issue.createdAt,
          resolvedAt: DateTime.now(),
          assignedMaintenanceId: issue.assignedMaintenanceId,
        );
        _assignedIssues.removeWhere((i) => i.id == issue.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'All Issues'),
              Tab(text: 'Assigned to Me'),
              Tab(text: 'Resolved'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildIssuesList(_allIssues),
                _buildIssuesList(_assignedIssues),
                _buildIssuesList(
                  _allIssues.where((i) => i.status == IssueStatus.resolved).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssuesList(List<Issue> issues) {
    if (issues.isEmpty) {
      return const Center(child: Text('No issues to display'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: issues.length,
      itemBuilder: (context, index) {
        final issue = issues[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Text(issue.title),
            subtitle: Text('Status: ${issue.status.name}'),
            leading: CircleAvatar(
              backgroundColor: _getPriorityColor(issue.priority),
              child: Text(issue.priority.name[0].toUpperCase()),
            ),
            trailing: _buildActionButtons(issue),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Description: ${issue.description}'),
                    const SizedBox(height: 8),
                    Text('Priority: ${issue.priority.name.toUpperCase()}'),
                    const SizedBox(height: 8),
                    Text('Reported: ${issue.createdAt.toString()}'),
                    if (issue.resolvedAt != null) ...[
                      const SizedBox(height: 8),
                      Text('Resolved: ${issue.resolvedAt.toString()}'),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            // Navigate to chat screen
                            Navigator.pushNamed(
                              context,
                              '/chat',
                              arguments: issue,
                            );
                          },
                          child: const Text('Chat'),
                        ),
                        const SizedBox(width: 8),
                        if (issue.status == IssueStatus.resolved)
                          ElevatedButton(
                            onPressed: () {
                              // Show resolution details
                              _showResolutionDetails(issue);
                            },
                            child: const Text('View Details'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(Issue issue) {
    if (issue.assignedMaintenanceId == widget.user.id) {
      if (issue.status == IssueStatus.inProgress) {
        return ElevatedButton(
          onPressed: () => _resolveIssue(issue),
          child: const Text('Resolve'),
        );
      }
    } else if (issue.status == IssueStatus.reported || 
               issue.status == IssueStatus.acknowledged) {
      return ElevatedButton(
        onPressed: () => _assignIssue(issue),
        child: const Text('Assign'),
      );
    }
    return const SizedBox.shrink();
  }

  void _showResolutionDetails(Issue issue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolution Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Issue: ${issue.title}'),
            const SizedBox(height: 8),
            Text('Resolved: ${issue.resolvedAt.toString()}'),
            const SizedBox(height: 8),
            const Text('Resolution: Issue resolved through remote assistance'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(IssuePriority priority) {
    switch (priority) {
      case IssuePriority.low:
        return Colors.green;
      case IssuePriority.medium:
        return Colors.orange;
      case IssuePriority.high:
        return Colors.red;
      case IssuePriority.critical:
        return Colors.red.shade900;
    }
  }
}
