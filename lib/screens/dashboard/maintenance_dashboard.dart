import 'package:flutter/material.dart';
import '../../models/user_model.dart' as app_models;
import '../../models/issue_model.dart';
import '../../services/firebase_service.dart';
import '../../models/operator_model.dart';
import '../../models/private_chat_model.dart';
import '../../screens/chat/chat_screen.dart';

class MaintenanceDashboard extends StatefulWidget {
  final app_models.User user;

  const MaintenanceDashboard({super.key, required this.user});

  @override
  State<MaintenanceDashboard> createState() => _MaintenanceDashboardState();
}

class _MaintenanceDashboardState extends State<MaintenanceDashboard> {
  final Map<String, String?> _selectedInterventionTypes =
      {}; // Map to store selected intervention type for each issue

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Maintenance Dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Issues'),
              Tab(text: 'All Issues'),
              Tab(text: 'Operators'),
              Tab(text: 'Admins'),
              Tab(text: 'Resolved'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMyIssuesTab(),
            _buildAllIssuesTab(),
            _buildOperatorsTab(),
            _buildAdminsTab(),
            _buildResolvedIssuesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMyIssuesTab() {
    return StreamBuilder<List<Issue>>(
      stream: FirebaseService.getAllIssues(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final issues = snapshot.data ?? [];
        final myIssues = issues
            .where(
              (issue) =>
                  issue.assignedMaintenanceId == widget.user.id &&
                  issue.status != IssueStatus.resolved,
            )
            .toList();

        if (myIssues.isEmpty) {
          return const Center(child: Text('No issues assigned to you'));
        }

        return _buildIssuesList(myIssues, showAssignButton: false);
      },
    );
  }

  Widget _buildAllIssuesTab() {
    return StreamBuilder<List<Issue>>(
      stream: FirebaseService.getAllIssues(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final issues = snapshot.data ?? [];
        final activeIssues = issues
            .where((issue) => issue.status != IssueStatus.resolved)
            .toList();

        if (activeIssues.isEmpty) {
          return const Center(child: Text('No active issues'));
        }

        return _buildIssuesList(activeIssues, showAssignButton: true);
      },
    );
  }

  Widget _buildOperatorsTab() {
    return StreamBuilder<List<Operator>>(
      stream: FirebaseService.getAllOperators(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final operators = snapshot.data ?? [];

        if (operators.isEmpty) {
          return const Center(child: Text('No operators found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: operators.length,
          itemBuilder: (context, index) {
            final operator = operators[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(operator.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Matricule: ${operator.matricule}'),
                    if (operator.assignedMachines.isNotEmpty)
                      Text('Machines: ${operator.assignedMachines.join(', ')}'),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.chat, color: Colors.blue),
                  onPressed: () => _startChatWithOperator(context, operator),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAdminsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService.getAllAdmins(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final admins = snapshot.data ?? [];

        if (admins.isEmpty) {
          return const Center(child: Text('No admins found'));
        }

        return StreamBuilder<List<PrivateChat>>(
          stream: FirebaseService.getUserPrivateChats(widget.user.id),
          builder: (context, chatSnapshot) {
            final chats = chatSnapshot.data ?? [];

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: admins.length,
              itemBuilder: (context, index) {
                final admin = admins[index];
                final adminId = admin['uid'] ?? '';
                final adminName = admin['name'] ?? 'Admin';

                // Find existing chat with this admin
                final unreadCount = _getUnreadCountForAdmin(chats, adminId);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Stack(
                      children: [
                        const Icon(Icons.admin_panel_settings),
                        if (unreadCount > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 12,
                                minHeight: 12,
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(adminName),
                    subtitle: Text(
                      'Admin ID: ${adminId.isNotEmpty && adminId.length >= 8 ? adminId.substring(0, 8) + '...' : adminId}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.chat, color: Colors.blue),
                      onPressed: () =>
                          _startChatWithAdmin(context, adminId, adminName),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildResolvedIssuesTab() {
    return StreamBuilder<List<Issue>>(
      stream: FirebaseService.getAllIssues(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final issues = snapshot.data ?? [];
        final resolvedIssues = issues
            .where((issue) => issue.status == IssueStatus.resolved)
            .toList();

        if (resolvedIssues.isEmpty) {
          return const Center(child: Text('No resolved issues'));
        }

        return _buildIssuesList(resolvedIssues, showAssignButton: false);
      },
    );
  }

  Widget _buildIssuesList(
    List<Issue> issues, {
    required bool showAssignButton,
  }) {
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
            trailing: _buildActionButtons(issue, showAssignButton),
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
                    Text('Reported: ${_formatDate(issue.createdAt)}'),
                    if (issue.resolvedAt != null) ...[
                      const SizedBox(height: 8),
                      Text('Resolved: ${_formatDate(issue.resolvedAt!)}'),
                    ],
                    if (issue.assignedMaintenanceId != null) ...[
                      const SizedBox(height: 8),
                      Text('Assigned to: ${issue.assignedMaintenanceId}'),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Intervention Type: ${issue.interventionType ?? "Not specified"}',
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value:
                              _selectedInterventionTypes[issue.id] ??
                              issue.interventionType,
                          items: const [
                            DropdownMenuItem(
                              value: 'Remote',
                              child: Text('Remote'),
                            ),
                            DropdownMenuItem(
                              value: 'In Person',
                              child: Text('In Person'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedInterventionTypes[issue.id] = value;
                            });
                            _assignIssue(issue); // Call to update Firebase
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => _startIssueChat(context, issue),
                          child: const Text('Chat about Issue'),
                        ),
                        const SizedBox(width: 8),
                        if (issue.status == IssueStatus.resolved)
                          ElevatedButton(
                            onPressed: () => _showResolutionDetails(issue),
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

  Widget _buildActionButtons(Issue issue, bool showAssignButton) {
    if (issue.assignedMaintenanceId == widget.user.id) {
      if (issue.status == IssueStatus.inProgress) {
        return ElevatedButton(
          onPressed: () => _resolveIssue(issue),
          child: const Text('Resolve'),
        );
      }
    } else if (showAssignButton &&
        (issue.status == IssueStatus.reported ||
            issue.status == IssueStatus.acknowledged)) {
      return ElevatedButton(
        onPressed: () => _assignIssue(issue),
        child: const Text('Assign to Me'),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _assignIssue(Issue issue) async {
    final currentContext = context;
    try {
      final updatedIssue = issue.copyWith(
        status: IssueStatus.inProgress,
        assignedMaintenanceId: widget.user.id,
        interventionType:
            _selectedInterventionTypes[issue.id] ??
            issue.interventionType, // Include intervention type
      );
      await FirebaseService.updateIssue(updatedIssue);
      if (!mounted) return;
      ScaffoldMessenger.of(
        currentContext,
      ).showSnackBar(const SnackBar(content: Text('Issue assigned to you')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        currentContext,
      ).showSnackBar(SnackBar(content: Text('Error assigning issue: $e')));
    }
  }

  Future<void> _resolveIssue(Issue issue) async {
    final currentContext = context;
    try {
      final updatedIssue = issue.copyWith(
        status: IssueStatus.resolved,
        resolvedAt: DateTime.now(),
      );
      await FirebaseService.updateIssue(updatedIssue);
      if (!mounted) return;
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(content: Text('Issue resolved successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        currentContext,
      ).showSnackBar(SnackBar(content: Text('Error resolving issue: $e')));
    }
  }

  Future<void> _startIssueChat(BuildContext context, Issue issue) async {
    try {
      // Get all operators to find the one who reported the issue
      final operators = await FirebaseService.getAllOperators().first;
      final operator = operators.firstWhere(
        (op) => op.matricule == issue.reporterId,
        orElse: () => Operator(
          matricule: issue.reporterId,
          name: 'Unknown Operator',
          savedPhrases: const [],
          assignedMachines: const [],
        ),
      );

      await _startChatWithOperator(context, operator, issueId: issue.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error starting chat: $e')));
    }
  }

  Future<void> _startChatWithOperator(
    BuildContext context,
    Operator operator, {
    String? issueId,
  }) async {
    try {
      // Check if chat already exists
      final existingChatId = await FirebaseService.findExistingPrivateChat(
        widget.user.id,
        operator.matricule,
      );

      String chatId;
      if (existingChatId != null) {
        chatId = existingChatId;
      } else {
        // Create new chat
        chatId = await FirebaseService.createPrivateChat(
          widget.user.id,
          widget.user.name,
          widget.user.role.name,
          operator.matricule,
          operator.name,
          'maintenance_service',
        );
      }

      // Link chat to issue if provided
      if (issueId != null) {
        await FirebaseService.linkChatToIssue(chatId, issueId);
      }

      // Navigate to chat screen
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatId,
            isPrivateChat: true,
            title: 'Chat with ${operator.name}',
            user: widget.user,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error starting chat: $e')));
    }
  }

  int _getUnreadCountForAdmin(List<PrivateChat> chats, String adminId) {
    for (final chat in chats) {
      if (chat.participant1Id == adminId || chat.participant2Id == adminId) {
        return chat.getUnreadCount(widget.user.id);
      }
    }
    return 0;
  }

  Future<void> _startChatWithAdmin(
    BuildContext context,
    String adminId,
    String adminName,
  ) async {
    try {
      // Check if chat already exists
      final existingChatId = await FirebaseService.findExistingPrivateChat(
        widget.user.id,
        adminId,
      );

      String chatId;
      if (existingChatId != null) {
        chatId = existingChatId;
      } else {
        // Create new chat with admin
        chatId = await FirebaseService.createPrivateChat(
          widget.user.id,
          widget.user.name,
          widget.user.role.name,
          adminId,
          adminName,
          'admin',
        );
      }

      // Navigate to chat screen
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatId,
            isPrivateChat: true,
            title: 'Chat with $adminName',
            user: widget.user,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error starting chat: $e')));
    }
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
            Text('Resolved: ${_formatDate(issue.resolvedAt!)}'),
            const SizedBox(height: 8),
            const Text(
              'Resolution: Issue resolved through maintenance service',
            ),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
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
