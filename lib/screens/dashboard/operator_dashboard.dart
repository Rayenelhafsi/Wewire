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

class _OperatorDashboardState extends State<OperatorDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String? _currentlyWorkingMachineId;
  String? _currentSessionId;
  DateTime? _sessionStartTime;
  Timer? _analyticsUpdateTimer;
  Timer? _workingTimeRealtimeTimer;
  Timer? _stoppedTimeRealtimeTimer;
  int _workingTimeSeconds = 0;
  StreamSubscription<String>? _globalScanSubscription;
  StreamSubscription<String>?
  _rfidSubscription; // Add field for RFID subscription

  String? lastScannedUid; // Add this field to hold last scanned UID
  String? currentScanSessionUid; // Track UID for current scanning session

  String? _rfidMismatchMessage; // New state for mismatch message

  // Store all subscriptions to cancel on dispose
  final List<StreamSubscription> _subscriptions = [];

  bool _isCurrentlyWorking = false;
  bool analyticsUpdatesEnabled = true; // Add this field to track analytics updates

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchLastScannedUidOnInit();
    _setupGlobalScanListener();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _globalScanSubscription?.cancel();
    _rfidSubscription?.cancel(); // Cancel RFID subscription on dispose
    _analyticsUpdateTimer?.cancel();
    _workingTimeRealtimeTimer?.cancel();
    _stoppedTimeRealtimeTimer?.cancel();
    // Cancel all stored subscriptions
    for (final sub in _subscriptions) {
      sub.cancel();
    }
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
      debugPrint('Error fetching last scanned UID: $e');
    }
  }

  void _setupGlobalScanListener() {
    // Listen to machines assigned to the operator
    final machinesSub =
        FirebaseService.getMachinesByAssignedOperator(widget.user.id).listen((
          machines,
        ) {
          if (machines.isNotEmpty) {
            // Set up listeners for each machine's RFID scans
            for (final machine in machines) {
              final rfidSub = FirebaseService.listenForRfidTagScans(machine.id)
                  .listen((tagUid) {
                    debugPrint(
                      'Global scan listener: RFID tag detected: $tagUid for machine: ${machine.id}',
                    );
                    // Update the global lastScannedUid whenever any scan occurs
                    setState(() {
                      lastScannedUid = tagUid;
                    });
                  });
              _subscriptions.add(rfidSub);
            }
          }
        });
    _subscriptions.add(machinesSub);
  }

  void _startWork(Machine machine) {
    debugPrint(
      'Start Work button clicked for machine: ${machine.name}',
    ); // Debug print
    // Show form for cable reference and quantity objective
    final cableReferenceController = TextEditingController();
    final quantityObjectiveController = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Start Work'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Machine: ${machine.name}'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: cableReferenceController,
                  decoration: const InputDecoration(
                    labelText: 'Cable Reference',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter cable reference';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: quantityObjectiveController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity Objective',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter quantity objective';
                    }
                    final num = int.tryParse(value);
                    if (num == null || num <= 0) {
                      return 'Please enter a valid positive number';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!_formKey.currentState!.validate()) {
                return;
              }
              final cableReference = cableReferenceController.text.trim();
              final quantityObjective = int.parse(
                quantityObjectiveController.text.trim(),
              );
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
              debugPrint(
                'Starting RFID scan for machine: $machineId at $scanStartTime',
              ); // Debug print
              if (machineId.isEmpty) {
                // Cannot proceed without machine id
                debugPrint('Error: Machine id is empty'); // Debug print
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Machine id not found.')),
                  );
                }
                return;
              }

              debugPrint(
                'Setting up RFID stream subscription...',
              ); // Debug print
              debugPrint(
                'About to call listenForRfidTagScans with machineId: $machineId',
              ); // Debug print

              // Add a small delay to allow the listener to be set up before processing scans
              // This helps avoid processing cached/previous scans
              bool isListeningActive = false;
              late StreamSubscription<String> subscription;

              _rfidSubscription?.cancel(); // Cancel any existing subscription
              _rfidSubscription = FirebaseService.listenForRfidTagScans(machineId).listen((
                tagUid,
              ) async {
                debugPrint('RFID tag detected: $tagUid'); // Debug print

                // Only start processing scans after a brief delay to avoid cached data
                if (!isListeningActive) {
                  debugPrint(
                    'Ignoring initial/cached RFID scan: $tagUid',
                  ); // Debug print
                  return;
                }

                // Only process the scan if we haven't processed one in this session yet
                if (currentScanSessionUid == null) {
                  debugPrint(
                    'Processing new RFID scan: $tagUid',
                  ); // Debug print

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
                      debugPrint(
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
                  // await _rfidSubscription?.cancel();

                  // Update operator Firestore document if UID tag missing
                  await FirebaseService.updateOperatorRfidTagIfMissing(
                    operatorMatricule,
                    tagUid,
                  );

                  // Start work on machine
                  await _startWorkOnMachine(
                    machine,
                    cableReference,
                    quantityObjective,
                  );
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
                await _rfidSubscription?.cancel();
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

  Future<void> _startWorkOnMachine(
    Machine machine,
    String cableReference,
    int quantityObjective,
  ) async {
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
        issueTitle: '',
        issueDescription: '',
        interventionType: InterventionType.none,
        startTime: startTime,
        status: SessionStatus.inProgress, // In progress status for active work
        cableReference: cableReference,
        quantityObjective: quantityObjective,
      );

      print('DEBUG: Creating session with ID: $sessionId');
      // Save the session to Firestore
      await FirebaseService.createSession(newSession);
      print('DEBUG: Session created successfully: $sessionId');

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

      // Do NOT reset analytics fields to zero when starting work
      // Instead, just start the working time timer and increment from the existing value
      setState(() {
        _currentlyWorkingMachineId = machine.id;
        _currentSessionId = sessionId;
        _sessionStartTime = startTime;
        _workingTimeSeconds = 0;
        _isCurrentlyWorking = true;
      });

      // Start realtime working time timer
      _workingTimeRealtimeTimer?.cancel();
      _workingTimeRealtimeTimer = Timer.periodic(const Duration(seconds: 1), (
        timer,
      ) async {
        if (analyticsUpdatesEnabled) {
          final analytics = await FirebaseService.getMachineAnalytics(
            machine.id,
          );
          if (analytics != null) {
            await FirebaseService.updateMachineAnalytics(machine.id, {
              'totalWorkingTime': analytics.totalWorkingTime.inSeconds + 1,
              'lastUpdated': DateTime.now().toIso8601String(),
            });
          }
        }
      });

      // Stop realtime stopped time timer when starting work
      _stoppedTimeRealtimeTimer?.cancel();
      _stoppedTimeRealtimeTimer = null;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Started working on ${machine.name}')),
        );
      }
      print('DEBUG: _startWorkOnMachine completed successfully');
    } catch (e) {
      print('ERROR in _startWorkOnMachine: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start work: $e')));
      }
    }
  }

  void _stopWork() {
    // Show form dialog to enter producedQuantity and scrapQuantity
    final producedQuantityController = TextEditingController();
    final scrapQuantityController = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Stop Work'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Machine: ${_currentlyWorkingMachineId ?? ''}'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: producedQuantityController,
                  decoration: const InputDecoration(
                    labelText: 'Produced Quantity',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter produced quantity';
                    }
                    final num = int.tryParse(value);
                    if (num == null || num < 0) {
                      return 'Please enter a valid non-negative number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: scrapQuantityController,
                  decoration: const InputDecoration(
                    labelText: 'Scrap Quantity',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter scrap quantity';
                    }
                    final num = int.tryParse(value);
                    if (num == null || num < 0) {
                      return 'Please enter a valid non-negative number';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!_formKey.currentState!.validate()) {
                return;
              }
              final producedQuantity = int.parse(
                producedQuantityController.text.trim(),
              );
              final scrapQuantity = int.parse(
                scrapQuantityController.text.trim(),
              );
              Navigator.pop(context);
              await _stopWorkOnMachine(producedQuantity, scrapQuantity);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _stopWorkOnMachine(
    int producedQuantity,
    int scrapQuantity,
  ) async {
    try {
      if (_currentSessionId != null && _sessionStartTime != null) {
        final endTime = DateTime.now();
        final workingDuration = endTime.difference(_sessionStartTime!);

        // Fetch the existing session to preserve cableReference and quantityObjective
        final existingSession = await FirebaseService.getSessionById(
          _currentSessionId!,
        );

        if (existingSession == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to find existing session')),
            );
          }
          return;
        }

        // Create updated session with preserved fields
        final updatedSession = Session(
          id: _currentSessionId!,
          operatorMatricule: widget.user.id,
          technicianMatricule: existingSession.technicianMatricule,
          machineReference: _currentlyWorkingMachineId ?? '',
          issueTitle: existingSession.issueTitle,
          issueDescription: existingSession.issueDescription,
          interventionType:
              existingSession.interventionType, // Preserve original value
          startTime: _sessionStartTime!,
          endTime: endTime,
          status: SessionStatus.closed,
          cableReference:
              existingSession.cableReference, // Preserve original value
          quantityObjective:
              existingSession.quantityObjective, // Preserve original value
          producedQuantity: producedQuantity,
          scrapQuantity: scrapQuantity,
        );

        // Update the session in Firestore
        await FirebaseService.updateSession(updatedSession);

        // Directly update analytics for stop work event
        await FirebaseService.updateWorkingTime(
          _currentlyWorkingMachineId ?? '',
          workingDuration,
        );
        await FirebaseService.updateStoppedReadyForWorkTime(
          _currentlyWorkingMachineId ?? '',
          Duration.zero,
        );
        // Start stopped time and stopped ready for work time in realtime
        _stoppedTimeRealtimeTimer = Timer.periodic(const Duration(seconds: 1), (
          timer,
        ) async {
          if (_currentlyWorkingMachineId != null && analyticsUpdatesEnabled) {
            await FirebaseService.incrementStoppedTimesRealtime(
              _currentlyWorkingMachineId!,
              1,
            );
          }
        });

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
          final totalStoppedTimeWithSession =
              analytics.totalStoppedTime + workingDuration;

          await FirebaseService.updateMachineAnalytics(
            _currentlyWorkingMachineId ?? '',
            {
              'dailyStoppedTime': MachineAnalytics.durationMapToJson(
                updatedDailyStoppedTime,
              ),
              'totalStoppedTime': totalStoppedTimeWithSession.inSeconds,
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

        // Stop realtime working time timer
        _workingTimeRealtimeTimer?.cancel();
        _workingTimeRealtimeTimer = null;
        // Do NOT stop _stoppedTimeRealtimeTimer here. Let it run until work is started again.

        // Do NOT set _currentlyWorkingMachineId to null here!
        // Only set it to null when starting work again.
        setState(() {
          _currentSessionId = null;
          _sessionStartTime = null;
          _isCurrentlyWorking = false;
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
                initialValue: selectedPriority,
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
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter an issue title'),
                    ),
                  );
                }
                return;
              }

              if (descriptionController.text.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a description')),
                  );
                }
                return;
              }

              if (selectedPriority == null) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a priority level'),
                    ),
                  );
                }
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

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Issue reported successfully'),
                    ),
                  );
                }
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

  void _toggleAnalyticsUpdates(bool enabled) {
    setState(() {
      analyticsUpdatesEnabled = enabled;
    });
    if (!enabled) {
      _workingTimeRealtimeTimer?.cancel();
      _stoppedTimeRealtimeTimer?.cancel();
      _analyticsUpdateTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_rfidMismatchMessage != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color.fromARGB(255, 0, 0, 0),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _rfidMismatchMessage!,
                    style: const TextStyle(
                      color: Color.fromARGB(255, 0, 0, 0),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Color.fromARGB(255, 0, 0, 0),
                  ),
                  onPressed: () {
                    setState(() {
                      _rfidMismatchMessage = null;
                    });
                  },
                ),
              ],
            ),
          ),
        Padding(
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
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Scaffold(
            appBar: AppBar(
              bottom: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'My Machines'),
                  Tab(text: 'Reported Issues'),
                  Tab(text: 'My Chats'),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(analyticsUpdatesEnabled ? Icons.pause : Icons.play_arrow),
                  tooltip: analyticsUpdatesEnabled ? 'Stop Analytics Updates' : 'Start Analytics Updates',
                  onPressed: () => _toggleAnalyticsUpdates(!analyticsUpdatesEnabled),
                ),
              ],
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                // My Machines tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
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
                        return const Center(
                          child: Text('No machines available'),
                        );
                      }
                      return ListView.builder(
                        itemCount: machines.length,
                        itemBuilder: (context, index) {
                          final machine = machines[index];
                          final isCurrentlyWorkingOnThisMachine =
                              _isCurrentlyWorking &&
                              _currentlyWorkingMachineId == machine.id;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(
                                  machine.status,
                                ),
                                child: const Icon(
                                  Icons.build,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(machine.name),
                              subtitle: Text(
                                '${machine.model} - ${machine.location}',
                              ),
                              trailing: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isCurrentlyWorkingOnThisMachine)
                                    TextButton(
                                      onPressed: _stopWork,
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Stop Working',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    )
                                  else
                                    TextButton(
                                      onPressed: () => _startWork(machine),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Start Working',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  TextButton(
                                    onPressed: () => _reportIssue(machine),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Report Issue',
                                      style: TextStyle(fontSize: 12),
                                    ),
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
                // Reported Issues tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
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
                        return const Center(
                          child: Text('No issues reported yet'),
                        );
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
                                backgroundColor: _getPriorityColor(
                                  issue.priority,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                // My Chats tab
                Padding(
                  padding: const EdgeInsets.all(16.0),
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
                                            chat.participant1Name ==
                                                widget.user.name
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
          ),
        ),
      ],
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
