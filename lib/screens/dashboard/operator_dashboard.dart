import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import intl package
import '../../models/user_model.dart' as app_models;
import '../../models/machine_model.dart';
import '../../models/issue_model.dart';
import '../../models/private_chat_model.dart';
import '../../models/session_model.dart';
import '../../models/machine_analytics_model.dart';
import '../../services/firebase_service.dart';
import '../../screens/chat/chat_screen.dart';

class OperatorDashboard extends StatefulWidget {
  final app_models.User user;

  const OperatorDashboard({super.key, required this.user});

  @override
  State<OperatorDashboard> createState() => _OperatorDashboardState();
}

class _OperatorDashboardState extends State<OperatorDashboard> {
  String? _currentlyWorkingMachineId;
  String? _currentSessionId;
  DateTime? _sessionStartTime;
  Timer? _analyticsUpdateTimer;
  StreamSubscription<String>? _globalScanSubscription;

  String? lastScannedUid; // Add this field to hold last scanned UID
  String? currentScanSessionUid; // Track UID for current scanning session

  String? _rfidMismatchMessage; // New state for mismatch message

  @override
  void initState() {
    super.initState();
    _fetchLastScannedUidOnInit();
    _setupGlobalScanListener();
  }

  @override
  void dispose() {
    _globalScanSubscription?.cancel();
    _analyticsUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLastScannedUidOnInit() async {
    try {
      // Listen to the stream and get the first emission
      final machinesStream = FirebaseService.getMachinesByAssignedOperator(
        widget.user.id,
      );
      final machines = await machinesStream.first;

      if (machines.isNotEmpty) {
        // For each assigned machine, fetch the last scan and find the most recent
        String? mostRecentUid;

        for (final machine in machines) {
          final uid = await FirebaseService.fetchLastScanForMachine(machine.id);
          if (uid != null) {
            // Since we don't have timestamps in the current implementation,
            // we'll just take the first non-null UID we find
            // In a more complete implementation, you'd store timestamps with scans
            mostRecentUid = uid;
            break; // For now, just use the first one found
          }
        }

        if (mostRecentUid != null) {
          setState(() {
            lastScannedUid = mostRecentUid;
          });
        }
      }
    } catch (e) {
      print('Error fetching last scanned UID: $e');
    }
  }

  void _setupGlobalScanListener() {
    // Listen to machines assigned to the operator
    FirebaseService.getMachinesByAssignedOperator(widget.user.id).listen((
      machines,
    ) {
      if (machines.isNotEmpty) {
        // Set up listeners for each machine's RFID scans
        for (final machine in machines) {
          FirebaseService.listenForRfidTagScans(machine.id).listen((tagUid) {
            print(
              'Global scan listener: RFID tag detected: $tagUid for machine: ${machine.id}',
            );
            // Update the global lastScannedUid whenever any scan occurs
            setState(() {
              lastScannedUid = tagUid;
            });
          });
        }
      }
    });
  }

  void _startWork(Machine machine) {
    print(
      'Start Work button clicked for machine: ${machine.name}',
    ); // Debug print
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Work'),
        content: Text(
          'Are you sure you want to start working on ${machine.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              // Show dialog prompting operator to pass RFID tag
              final rfidConfirmed = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Pass your RFID tag'),
                    content: const Text(
                      'Please pass your RFID tag to the reader.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Start Scanning'),
                      ),
                    ],
                  );
                },
              );

              if (rfidConfirmed == false) {
                // Operator cancelled RFID tag prompt
                return;
              }

              // Clear the current scan session UID to ensure we wait for a new scan
              currentScanSessionUid = null;

              // Record the time when user confirmed to start scanning
              final scanStartTime = DateTime.now();

              // Listen for RFID tag scan from Realtime Database
              final machineId = machine.id;
              final operatorMatricule = widget.user.id;
              print(
                'Starting RFID scan for machine: $machineId at $scanStartTime',
              ); // Debug print
              if (machineId.isEmpty) {
                // Cannot proceed without machine id
                print('Error: Machine id is empty'); // Debug print
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Machine id not found.')),
                  );
                }
                return;
              }

              print('Setting up RFID stream subscription...'); // Debug print
              print(
                'About to call listenForRfidTagScans with machineId: $machineId',
              ); // Debug print

              // Add a small delay to allow the listener to be set up before processing scans
              // This helps avoid processing cached/previous scans
              bool isListeningActive = false;
              late StreamSubscription<String> subscription;

              subscription = FirebaseService.listenForRfidTagScans(machineId).listen((
                tagUid,
              ) async {
                print('RFID tag detected: $tagUid'); // Debug print

                // Only start processing scans after a brief delay to avoid cached data
                if (!isListeningActive) {
                  print(
                    'Ignoring initial/cached RFID scan: $tagUid',
                  ); // Debug print
                  return;
                }

                // Only process the scan if we haven't processed one in this session yet
                if (currentScanSessionUid == null) {
                  print('Processing new RFID scan: $tagUid'); // Debug print

                  // Check if operator has RFID tag assigned
                  final operatorDoc = await FirebaseService.getOperator(
                    operatorMatricule,
                  );
                  final operatorRfidTag = operatorDoc?.rfidTagUid;

                  if (operatorRfidTag == null || operatorRfidTag.isEmpty) {
                    // Operator does not have RFID tag assigned, check if tag is owned by another operator
                    final existingOwner =
                        await FirebaseService.getOperatorByRfidTag(tagUid);
                    if (existingOwner != null &&
                        existingOwner != operatorMatricule) {
                      print(
                        'RFID tag $tagUid is already owned by operator $existingOwner',
                      );
                      if (mounted) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && context.mounted) {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('RFID Tag Already Assigned'),
                                content: Text(
                                  'RFID tag ($tagUid) is already assigned to another operator. '
                                  'Please use a different RFID tag or contact your administrator.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          }
                        });
                      }
                      return;
                    }

                    // Assign the tag to the operator
                    final assigned =
                        await FirebaseService.assignRfidTagToOperator(
                          operatorMatricule,
                          tagUid,
                        );
                    if (!assigned) {
                      print(
                        'Failed to assign RFID tag $tagUid to operator $operatorMatricule',
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Failed to assign RFID tag to operator.',
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    print(
                      'RFID tag $tagUid assigned to operator $operatorMatricule',
                    );
                  } else {
                    // Operator has RFID tag assigned, verify scanned tag matches
                    if (operatorRfidTag != tagUid) {
                      print(
                        'Scanned RFID tag $tagUid does not match operator\'s assigned tag $operatorRfidTag',
                      );

                      // Show dialog instead of just snackbar
                      if (mounted) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && context.mounted) {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('RFID Tag Mismatch'),
                                content: Text(
                                  'Scanned RFID tag ($tagUid) does not match your assigned tag ($operatorRfidTag). '
                                  'Please use your assigned RFID tag to start working.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          }
                        });
                      }
                      return;
                    }
                  }

                  // Update both session and global UIDs
                  if (mounted) {
                    setState(() {
                      currentScanSessionUid = tagUid;
                      lastScannedUid = tagUid;
                    });
                  }

                  // Show dialog "I read your tag" using addPostFrameCallback to ensure valid context
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && context.mounted) {
                      showDialog(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Tag Read'),
                          content: Text(
                            'I read your tag you can start working on machine ${machine.id}.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                  });

                  // Cancel subscription after first tag read
                  await subscription.cancel();

                  // Update operator Firestore document if UID tag missing
                  await FirebaseService.updateOperatorRfidTagIfMissing(
                    operatorMatricule,
                    tagUid,
                  );

                  // Start work on machine
                  await _startWorkOnMachine(machine);
                } else {
                  print('Ignoring duplicate RFID scan: $tagUid'); // Debug print
                }
              });

              // Activate listening after a short delay to avoid processing cached data
              Future.delayed(const Duration(milliseconds: 500), () {
                isListeningActive = true;
                print('RFID listening now active for new scans'); // Debug print
              });

              // Optionally, add a timeout to cancel listening after some time (e.g., 30 seconds)
              Future.delayed(const Duration(seconds: 30), () async {
                await subscription.cancel();
                if (!mounted) return;
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('RFID tag read timed out.')),
                  );
                }
              });
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _startWorkOnMachine(Machine machine) async {
    print('DEBUG: _startWorkOnMachine called for machine: ${machine.name}');
    try {
      final startTime = DateTime.now();

      // Create a new session
      final sessionId = 'session_${startTime.millisecondsSinceEpoch}';
      final newSession = Session(
        id: sessionId,
        operatorMatricule: widget.user.id, // Assuming user.id is the matricule
        technicianMatricule: '', // Not assigned yet
        machineReference: machine.id,
        issueTitle: 'Work on ${machine.name}',
        issueDescription:
            'Operator ${widget.user.name} started working on ${machine.name}',
        startTime: startTime,
        status: SessionStatus.inProgress, // In progress status for active work
      );

      // Save the session to Firestore
      await FirebaseService.createSession(newSession);

      // Initialize or update machine analytics overview document with all required fields
      final existingAnalytics = await FirebaseService.getMachineAnalytics(
        machine.id,
      );
      if (existingAnalytics == null) {
        // Create new analytics with default values
        final newAnalytics = MachineAnalytics(
          machineId: machine.id,
          dailyStoppedTime: {},
          monthlyStoppedTime: {},
          yearlyStoppedTime: {},
          totalWorkingTime: Duration.zero,
          totalStoppedTime: Duration.zero,
          stoppedWithoutMaintenanceTime: Duration.zero,
          stoppedReadyForWorkTime: Duration.zero,
          maintenanceInProgressTime: Duration.zero,
          lastUpdated: DateTime.now(),
        );
        await FirebaseService.saveMachineAnalytics(newAnalytics);
      }

      // Update maintenance in progress time with zero initially
      await FirebaseService.updateMaintenanceInProgressTime(
        machine.id,
        Duration.zero,
      );

      // Start periodic analytics updates every 5 minutes
      _startPeriodicAnalyticsUpdates(machine.id, startTime);

      // Update state
      setState(() {
        _currentlyWorkingMachineId = machine.id;
        _currentSessionId = sessionId;
        _sessionStartTime = startTime;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Started working on ${machine.name}')),
      );
      print('DEBUG: _startWorkOnMachine completed successfully');
    } catch (e) {
      print('ERROR in _startWorkOnMachine: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to start work: $e')));
    }
  }

  void _startPeriodicAnalyticsUpdates(String machineId, DateTime startTime) {
    // Cancel any existing timer
    _analyticsUpdateTimer?.cancel();

    // Start new timer that fires every 5 minutes
    _analyticsUpdateTimer = Timer.periodic(const Duration(minutes: 5), (
      timer,
    ) async {
      final now = DateTime.now();
      final durationSinceLastUpdate = now.difference(startTime);

      // Update maintenance in progress time with actual duration
      await FirebaseService.updateMaintenanceInProgressTime(
        machineId,
        durationSinceLastUpdate,
      );

      // Also update lastUpdated timestamp
      await FirebaseService.updateMachineAnalytics(machineId, {
        'lastUpdated': now.toIso8601String(),
      });

      // Optionally, call aggregateMonthlyYearlyStats to keep aggregates updated
      await FirebaseService.aggregateMonthlyYearlyStats(machineId);

      print(
        'Periodic analytics update for machine $machineId: $durationSinceLastUpdate',
      );
    });
  }

  void _stopWork() {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Work'),
        content: const Text('Are you sure you want to stop working?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Stop work
              await _stopWorkOnMachine();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _stopWorkOnMachine() async {
    try {
      if (_currentSessionId != null && _sessionStartTime != null) {
        final endTime = DateTime.now();
        final workingDuration = endTime.difference(_sessionStartTime!);

        // Get the current session
        // For simplicity, we'll create a new session object with the end time
        // In a real app, you might want to fetch the existing session from Firestore
        final updatedSession = Session(
          id: _currentSessionId!,
          operatorMatricule: widget.user.id,
          technicianMatricule: '',
          machineReference: _currentlyWorkingMachineId ?? '',
          issueTitle: 'Work on machine',
          issueDescription: 'Operator ${widget.user.name} worked on machine',
          startTime: _sessionStartTime!,
          endTime: endTime,
          status: SessionStatus.closed,
        );

        // Update the session in Firestore
        await FirebaseService.updateSession(updatedSession);

        // Update machine analytics with actual working duration
        await FirebaseService.updateWorkingTime(
          _currentlyWorkingMachineId ?? '',
          workingDuration,
        );
        await FirebaseService.updateStoppedReadyForWorkTime(
          _currentlyWorkingMachineId ?? '',
          Duration.zero,
        );

        // Update totalStoppedTime and dailyStoppedTime for the stopped period
        final now = DateTime.now();
        final dateKey =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        // Fetch existing analytics
        final analytics = await FirebaseService.getMachineAnalytics(
          _currentlyWorkingMachineId ?? '',
        );

        if (analytics != null) {
          // Update dailyStoppedTime map
          final updatedDailyStoppedTime = Map<String, Duration>.from(
            analytics.dailyStoppedTime,
          );
          updatedDailyStoppedTime.update(
            dateKey,
            (existing) => existing + workingDuration,
            ifAbsent: () => workingDuration,
          );

          // Update totalStoppedTime
          final newTotalStoppedTime =
              analytics.totalStoppedTime + workingDuration;

          // Update monthly and yearly stopped time will be handled by aggregateMonthlyYearlyStats

          await FirebaseService.updateMachineAnalytics(
            _currentlyWorkingMachineId ?? '',
            {
              'dailyStoppedTime': MachineAnalytics.durationMapToJson(
                updatedDailyStoppedTime,
              ),
              'totalStoppedTime': newTotalStoppedTime.inSeconds,
              'lastUpdated': now.toIso8601String(),
            },
          );

          // Call aggregation method to update monthly and yearly stats
          await FirebaseService.aggregateMonthlyYearlyStats(
            _currentlyWorkingMachineId ?? '',
          );
        }

        // Stop the periodic analytics timer
        _analyticsUpdateTimer?.cancel();
        _analyticsUpdateTimer = null;

        // Update state
        setState(() {
          _currentlyWorkingMachineId = null;
          _currentSessionId = null;
          _sessionStartTime = null;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Stopped working')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to stop work: $e')));
    }
  }

  void _reportIssue(Machine machine) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    IssuePriority? selectedPriority;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Issue'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Machine: ${machine.name}'),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Issue Title*',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description*',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<IssuePriority>(
                value: selectedPriority,
                decoration: const InputDecoration(
                  labelText: 'Priority Level*',
                  border: OutlineInputBorder(),
                ),
                items: IssuePriority.values.map((priority) {
                  return DropdownMenuItem<IssuePriority>(
                    value: priority,
                    child: Text(priority.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (priority) {
                  selectedPriority = priority;
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a priority level';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Validate required fields
              if (titleController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter an issue title')),
                );
                return;
              }

              if (descriptionController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a description')),
                );
                return;
              }

              if (selectedPriority == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select a priority level'),
                  ),
                );
                return;
              }

              final newIssue = Issue(
                id: 'issue_${DateTime.now().millisecondsSinceEpoch}',
                machineId: machine.id,
                reporterId: widget.user.id,
                title: titleController.text,
                description: descriptionController.text,
                priority: selectedPriority!,
                status: IssueStatus.reported,
                createdAt: DateTime.now(),
              );

              // Save to Firestore
              try {
                await FirebaseService.saveIssue(newIssue);

                // Update machine analytics - machine is now stopped without maintenance
                await FirebaseService.updateStoppedWithoutMaintenanceTime(
                  machine.id,
                  Duration.zero, // Start tracking from now
                );

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Issue reported successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to report issue: $e')),
                );
              }
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Last Scanned RFID Tag UID:',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            lastScannedUid ?? 'No scans yet',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const Text(
            'My Machines',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Machine>>(
              stream: FirebaseService.getMachines(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final machines = snapshot.data ?? [];

                if (machines.isEmpty) {
                  return const Center(child: Text('No machines available'));
                }

                return ListView.builder(
                  itemCount: machines.length,
                  itemBuilder: (context, index) {
                    final machine = machines[index];
                    final isCurrentlyWorkingOnThisMachine =
                        _currentlyWorkingMachineId == machine.id;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(machine.status),
                          child: const Icon(Icons.build, color: Colors.white),
                        ),
                        title: Text(machine.name),
                        subtitle: Text(
                          '${machine.model} - ${machine.location}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isCurrentlyWorkingOnThisMachine)
                              ElevatedButton(
                                onPressed: _stopWork,
                                child: const Text('Stop Working'),
                              )
                            else
                              ElevatedButton(
                                onPressed: () => _startWork(machine),
                                child: const Text('Start Working'),
                              ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _reportIssue(machine),
                              child: const Text('Report Issue'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Reported Issues',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Issue>>(
              stream: FirebaseService.getAllIssues(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allIssues = snapshot.data ?? [];
                final reportedIssues = allIssues
                    .where((issue) => issue.reporterId == widget.user.id)
                    .toList();

                if (reportedIssues.isEmpty) {
                  return const Center(child: Text('No issues reported yet'));
                }

                return ListView.builder(
                  itemCount: reportedIssues.length,
                  itemBuilder: (context, index) {
                    final issue = reportedIssues[index];
                    return Card(
                      child: ListTile(
                        title: Text(issue.title),
                        subtitle: Text('Status: ${issue.status.name}'),
                        trailing: Chip(
                          label: Text(issue.priority.name.toUpperCase()),
                          backgroundColor: _getPriorityColor(issue.priority),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'My Chats',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<PrivateChat>>(
              stream: FirebaseService.getUserPrivateChats(widget.user.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final chats = snapshot.data ?? [];

                if (chats.isEmpty) {
                  return const Center(child: Text('No chats available'));
                }

                return ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          chat.participant1Name == widget.user.name
                              ? chat.participant2Name
                              : chat.participant1Name,
                        ),
                        subtitle: Text(
                          'Last message at: ${DateFormat.yMMMd().add_jm().format(chat.lastMessageAt.toDate())}',
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  chatId: chat.id,
                                  isPrivateChat: true,
                                  title:
                                      chat.participant1Name == widget.user.name
                                      ? chat.participant2Name
                                      : chat.participant1Name,
                                  user: widget.user,
                                ),
                              ),
                            );
                          },
                          child: const Text('Open Chat'),
                        ),
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

  Color _getStatusColor(MachineStatus status) {
    switch (status) {
      case MachineStatus.operational:
        return Colors.green;
      case MachineStatus.needsAttention:
        return Colors.orange;
      case MachineStatus.underMaintenance:
        return Colors.blue;
      case MachineStatus.broken:
        return Colors.red;
    }
  }

  Color _getPriorityColor(IssuePriority priority) {
    switch (priority) {
      case IssuePriority.low:
        return Colors.green.shade100;
      case IssuePriority.medium:
        return Colors.orange.shade100;
      case IssuePriority.high:
        return Colors.red.shade100;
      case IssuePriority.critical:
        return Colors.red.shade300;
    }
  }
}
