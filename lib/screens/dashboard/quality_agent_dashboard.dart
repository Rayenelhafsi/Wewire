import 'package:flutter/material.dart';
import '../../models/user_model.dart' as app_models;
import '../../models/issue_model.dart';

class QualityAgentDashboard extends StatefulWidget {
  final app_models.User user;

  const QualityAgentDashboard({super.key, required this.user});

  @override
  State<QualityAgentDashboard> createState() => _QualityAgentDashboardState();
}

class _QualityAgentDashboardState extends State<QualityAgentDashboard> {
  final List<Issue> _allIssues = [
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
  ];

  void _updateIssueStatus(Issue issue, IssueStatus newStatus) {
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
          status: newStatus,
          createdAt: issue.createdAt,
          resolvedAt: newStatus == IssueStatus.resolved ? DateTime.now() : null,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'All Issues'),
              Tab(text: 'My Reviews'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildIssuesList(_allIssues),
                _buildIssuesList(
                  _allIssues.where((i) => i.status != IssueStatus.reported).toList(),
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
            trailing: PopupMenuButton<IssueStatus>(
              onSelected: (status) => _updateIssueStatus(issue, status),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: IssueStatus.acknowledged,
                  child: Text('Acknowledge'),
                ),
                const PopupMenuItem(
                  value: IssueStatus.inProgress,
                  child: Text('Mark In Progress'),
                ),
                const PopupMenuItem(
                  value: IssueStatus.resolved,
                  child: Text('Mark Resolved'),
                ),
              ],
            ),
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
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Navigate to chat screen
                        Navigator.pushNamed(
                          context,
                          '/chat',
                          arguments: issue,
                        );
                      },
                      child: const Text('Start Chat'),
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
