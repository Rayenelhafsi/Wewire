import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../models/session_model.dart';
import '../../models/issue_model.dart';
import '../../models/machine_model.dart';
import '../../models/operator_model.dart';
import '../../models/technician_model.dart';
import '../../models/machine_analytics_model.dart';
import '../../services/firebase_service.dart';

class ChartData {
  final String category;
  final double value;
  final Color color;

  ChartData(this.category, this.value, this.color);
}

class OperatorTimeData {
  final String operatorName;
  final double hours;

  OperatorTimeData(this.operatorName, this.hours);
}

class TechnicianPerformanceData {
  final String technicianName;
  final double value;

  TechnicianPerformanceData(this.technicianName, this.value);
}

class OperatorHourlyData {
  final String hour;
  final double hours;

  OperatorHourlyData(this.hour, this.hours);
}

class AnalyticsDashboard extends StatefulWidget {
  const AnalyticsDashboard({super.key});

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  TimePeriod _selectedTimePeriod = TimePeriod.month;
  String? _selectedMachineId;
  String? _selectedOperatorId;
  String? _selectedTechnicianId;

  // New state variables for precise date inputs
  DateTime? _selectedDay;
  DateTime?
  _selectedMonth; // We'll use DateTime but only month and year are relevant
  int? _selectedYear;
  DateTime? _weekStartDate;
  DateTime? _weekEndDate;

  List<Machine> _machines = [];
  List<Operator> _operators = [];
  List<Technician> _technicians = [];
  List<Session> _sessions = [];
  List<Issue> _issues = [];
  Map<String, MachineAnalytics> _machineAnalytics = {};

  StreamSubscription<List<Machine>>? _machinesSubscription;
  StreamSubscription<List<Operator>>? _operatorsSubscription;
  StreamSubscription<List<Technician>>? _techniciansSubscription;
  StreamSubscription<List<Session>>? _sessionsSubscription;
  StreamSubscription<List<Issue>>? _issuesSubscription;
  Map<String, StreamSubscription<MachineAnalytics?>> _analyticsSubscriptions =
      {};

  bool _updatesActive = false; // Track if updates are active
  Timer? _updateTimer; // Timer for periodic updates

  // New state variable for toggle between time and percentage
  bool _showPercentage = false; // default to time display

  // Variable to control Firestore writes
  bool analyticsUpdatesEnabled = false;

  @override
  void initState() {
    super.initState();
    // Load technicians data immediately
    _loadTechnicians();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure technicians list is available when widget is built
    if (_technicians.isEmpty && _updatesActive) {
      _setupStreamListeners();
    }
  }

  @override
  void dispose() {
    _machinesSubscription?.cancel();
    _operatorsSubscription?.cancel();
    _techniciansSubscription?.cancel();
    _sessionsSubscription?.cancel();
    _issuesSubscription?.cancel();
    _updateTimer?.cancel();
    super.dispose();
  }

  void _loadTechnicians() {
    _techniciansSubscription = FirebaseService.getAllTechnicians().listen((
      technicians,
    ) {
      setState(() {
        _technicians = technicians;
      });
    });
  }

  void _setupStreamListeners() {
    _machinesSubscription = FirebaseService.getMachines().listen((
      machines,
    ) async {
      setState(() {
        _machines = machines;
      });

      // Initialize analytics for machines if missing
      for (var machine in machines) {
        await FirebaseService.initializeMachineAnalyticsIfMissing(machine.id);
      }

      // Cancel previous analytics subscriptions
      for (var sub in _analyticsSubscriptions.values) {
        sub.cancel();
      }
      _analyticsSubscriptions.clear();

      // Subscribe to analytics for each machine
      for (var machine in machines) {
        final sub = FirebaseService.streamMachineAnalytics(machine.id).listen((
          analytics,
        ) {
          print(
            'Received analytics update for machine ${machine.id}: ${analytics != null}',
          );
          setState(() {
            if (analytics != null) {
              _machineAnalytics[machine.id] = analytics;
            } else {
              _machineAnalytics.remove(machine.id);
            }
          });
        });
        _analyticsSubscriptions[machine.id] = sub;
      }
    });

    _operatorsSubscription = FirebaseService.getAllOperators().listen((
      operators,
    ) {
      setState(() {
        _operators = operators;
      });
    });

    _techniciansSubscription = FirebaseService.getAllTechnicians().listen((
      technicians,
    ) {
      setState(() {
        _technicians = technicians;
      });
    });

    _sessionsSubscription = FirebaseService.getSessionHistory().listen((
      sessions,
    ) {
      setState(() {
        _sessions = sessions;
      });
    });

    _issuesSubscription = FirebaseService.getAllIssues().listen((issues) {
      setState(() {
        _issues = issues;
      });
    });
  }

  void _toggleUpdates() {
    setState(() {
      _updatesActive = !_updatesActive;
      analyticsUpdatesEnabled = _updatesActive; // Control Firestore writes
    });
    if (_updatesActive) {
      _setupStreamListeners();
      _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        // Optionally force refresh from Firestore if needed
        // _refreshData();
      });
    } else {
      _machinesSubscription?.cancel();
      _operatorsSubscription?.cancel();
      _techniciansSubscription?.cancel();
      _sessionsSubscription?.cancel();
      _issuesSubscription?.cancel();
      for (var sub in _analyticsSubscriptions.values) {
        sub.cancel();
      }
      _analyticsSubscriptions.clear();
      _updateTimer?.cancel();
    }
  }

  Future<void> _refreshData() async {
    // Force refresh by re-subscribing to streams
    _machinesSubscription?.cancel();
    _operatorsSubscription?.cancel();
    _techniciansSubscription?.cancel();
    _sessionsSubscription?.cancel();
    _issuesSubscription?.cancel();

    setState(() {
      _machines = [];
      _operators = [];
      _technicians = [];
      _sessions = [];
      _issues = [];
    });

    _setupStreamListeners();
  }

  void _clearFilters() {
    setState(() {
      _selectedTimePeriod = TimePeriod.all;
      _selectedMachineId = null;
      _selectedOperatorId = null;
      _selectedTechnicianId = null;
      _selectedDay = null;
      _selectedMonth = null;
      _selectedYear = null;
      _weekStartDate = null;
      _weekEndDate = null;
    });
  }

  DateTime _getStartDateForPeriod(TimePeriod period) {
    final now = DateTime.now();
    switch (period) {
      case TimePeriod.day:
        return DateTime(now.year, now.month, now.day);
      case TimePeriod.week:
        return now.subtract(const Duration(days: 7));
      case TimePeriod.month:
        return DateTime(now.year, now.month, 1);
      case TimePeriod.year:
        return DateTime(now.year, 1, 1);
      case TimePeriod.all:
        return DateTime(now.year, now.month, now.day); // Fallback
    }
  }

  // Machine Statistics Calculations
  // Removed dynamic calculation to use Firestore data directly

  // Operator Statistics Calculations
  Map<String, dynamic> _calculateOperatorStatistics() {
    // Determine start and end date based on selected time period and inputs
    DateTime? startDate;
    DateTime? endDate;

    if (_selectedTimePeriod == TimePeriod.all) {
      startDate = null;
      endDate = null;
    } else {
      switch (_selectedTimePeriod) {
        case TimePeriod.day:
          if (_selectedDay != null) {
            startDate = DateTime(
              _selectedDay!.year,
              _selectedDay!.month,
              _selectedDay!.day,
            );
            endDate = startDate.add(const Duration(days: 1));
          }
          break;
        case TimePeriod.week:
          if (_weekStartDate != null && _weekEndDate != null) {
            startDate = DateTime(
              _weekStartDate!.year,
              _weekStartDate!.month,
              _weekStartDate!.day,
            );
            endDate = DateTime(
              _weekEndDate!.year,
              _weekEndDate!.month,
              _weekEndDate!.day,
            ).add(const Duration(days: 1));
          }
          break;
        case TimePeriod.month:
          if (_selectedMonth != null) {
            startDate = DateTime(
              _selectedMonth!.year,
              _selectedMonth!.month,
              1,
            );
            endDate = DateTime(
              _selectedMonth!.year,
              _selectedMonth!.month + 1,
              1,
            );
          }
          break;
        case TimePeriod.year:
          if (_selectedYear != null) {
            startDate = DateTime(_selectedYear!, 1, 1);
            endDate = DateTime(_selectedYear! + 1, 1, 1);
          }
          break;
        case TimePeriod.all:
          startDate = null;
          endDate = null;
          break;
      }

      // Fallback to default start date if no specific input provided
      startDate ??= _getStartDateForPeriod(_selectedTimePeriod);
      endDate ??= DateTime.now().add(const Duration(days: 1));
    }

    final filteredSessions = _sessions.where((session) {
      final sessionStart = session.startTime;
      if (startDate != null && endDate != null) {
        if (!(sessionStart.isAfter(startDate) &&
            sessionStart.isBefore(endDate))) {
          return false;
        }
      }
      return (_selectedOperatorId == null ||
              session.operatorMatricule == _selectedOperatorId) &&
          (_selectedMachineId == null ||
              session.machineReference == _selectedMachineId);
    }).toList();

    final operatorTime = <String, Duration>{};

    for (final session in filteredSessions.where((s) => s.endTime != null)) {
      final duration = session.endTime!.difference(session.startTime);
      operatorTime.update(
        session.operatorMatricule,
        (existing) => existing + duration,
        ifAbsent: () => duration,
      );
    }

    return {
      'operatorTime': operatorTime,
      'totalOperatorSessions': filteredSessions.length,
    };
  }

  // Technician Statistics Calculations
  Map<String, dynamic> _calculateTechnicianStatistics() {
    // Determine start and end date based on selected time period and inputs
    DateTime? startDate;
    DateTime? endDate;

    switch (_selectedTimePeriod) {
      case TimePeriod.day:
        if (_selectedDay != null) {
          startDate = DateTime(
            _selectedDay!.year,
            _selectedDay!.month,
            _selectedDay!.day,
          );
          endDate = startDate.add(const Duration(days: 1));
        }
        break;
      case TimePeriod.week:
        if (_weekStartDate != null && _weekEndDate != null) {
          startDate = DateTime(
            _weekStartDate!.year,
            _weekStartDate!.month,
            _weekStartDate!.day,
          );
          endDate = DateTime(
            _weekEndDate!.year,
            _weekEndDate!.month,
            _weekEndDate!.day,
          ).add(const Duration(days: 1));
        }
        break;
      case TimePeriod.month:
        if (_selectedMonth != null) {
          startDate = DateTime(_selectedMonth!.year, _selectedMonth!.month, 1);
          endDate = DateTime(
            _selectedMonth!.year,
            _selectedMonth!.month + 1,
            1,
          );
        }
        break;
      case TimePeriod.year:
        if (_selectedYear != null) {
          startDate = DateTime(_selectedYear!, 1, 1);
          endDate = DateTime(_selectedYear! + 1, 1, 1);
        }
        break;
      case TimePeriod.all:
        startDate = null;
        endDate = null;
        break;
    }

    // Fallback to default start date if no specific input provided
    startDate ??= _getStartDateForPeriod(_selectedTimePeriod);
    endDate ??= DateTime.now().add(const Duration(days: 1));

    final filteredIssues = _issues.where((issue) {
      return issue.createdAt.isAfter(startDate!) &&
          issue.createdAt.isBefore(endDate!) &&
          (_selectedTechnicianId == null ||
              issue.assignedMaintenanceId == _selectedTechnicianId);
    }).toList();

    final responseTimes = <String, List<Duration>>{};
    final repairTimes = <String, List<Duration>>{};

    for (final issue in filteredIssues.where(
      (i) => i.resolvedAt != null && i.assignedMaintenanceId != null,
    )) {
      // Response time (acknowledged - created)
      final acknowledgedTime = _getAcknowledgedTime(issue);
      if (acknowledgedTime != null) {
        final responseTime = acknowledgedTime.difference(issue.createdAt);
        responseTimes.update(
          issue.assignedMaintenanceId!,
          (existing) => [...existing, responseTime],
          ifAbsent: () => [responseTime],
        );
      }

      // Repair time (resolved - acknowledged)
      if (acknowledgedTime != null) {
        final repairTime = issue.resolvedAt!.difference(acknowledgedTime);
        repairTimes.update(
          issue.assignedMaintenanceId!,
          (existing) => [...existing, repairTime],
          ifAbsent: () => [repairTime],
        );
      }
    }

    return {
      'responseTimes': responseTimes,
      'repairTimes': repairTimes,
      'totalTechnicianIssues': filteredIssues.length,
    };
  }

  DateTime? _getAcknowledgedTime(Issue issue) {
    // This would ideally come from issue history, for now we'll use a simple approximation
    return issue.status.index > IssueStatus.reported.index
        ? issue.createdAt.add(const Duration(minutes: 30))
        : null;
  }

  MachineAnalytics? _aggregateAllMachineAnalytics() {
    if (_machineAnalytics.isEmpty) return null;

    Duration totalWorkingTime = Duration.zero;
    Duration totalStoppedTime = Duration.zero;
    Duration totalMaintenanceInProgressTime = Duration.zero;
    Duration totalStoppedWithoutMaintenanceTime = Duration.zero;
    Duration totalStoppedReadyForWorkTime = Duration.zero;

    for (var analytics in _machineAnalytics.values) {
      totalWorkingTime += analytics.totalWorkingTime;
      totalStoppedTime += analytics.totalStoppedTime;
      totalMaintenanceInProgressTime += analytics.maintenanceInProgressTime;
      totalStoppedWithoutMaintenanceTime +=
          analytics.stoppedWithoutMaintenanceTime;
      totalStoppedReadyForWorkTime += analytics.stoppedReadyForWorkTime;
    }

    // Provide default values for required parameters not included in aggregation
    return MachineAnalytics(
      machineId: 'all_machines',
      totalWorkingTime: totalWorkingTime,
      totalStoppedTime: totalStoppedTime,
      maintenanceInProgressTime: totalMaintenanceInProgressTime,
      stoppedWithoutMaintenanceTime: totalStoppedWithoutMaintenanceTime,
      dailyStoppedTime: {},
      monthlyStoppedTime: {},
      yearlyStoppedTime: {},
      stoppedReadyForWorkTime: totalStoppedReadyForWorkTime,
      lastUpdated: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final operatorStats = _calculateOperatorStatistics();
    final technicianStats = _calculateTechnicianStatistics();

    // Get the MachineAnalytics for the selected machine or null
    final machineAnalytics = _selectedMachineId != null
        ? _machineAnalytics[_selectedMachineId!]
        : _aggregateAllMachineAnalytics();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        actions: [
          IconButton(
            icon: Icon(_updatesActive ? Icons.pause : Icons.play_arrow),
            tooltip: _updatesActive ? 'Stop Updates' : 'Activate Updates',
            onPressed: _toggleUpdates,
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'Clear Filters',
            onPressed: _clearFilters,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters
            _buildFiltersSection(),
            const SizedBox(height: 20),

            // Machine Statistics
            if (machineAnalytics != null)
              _buildMachineStatisticsSection(machineAnalytics)
            else
              const Center(child: Text('No machine analytics data available')),
            const SizedBox(height: 20),

            // Operator Statistics
            _buildOperatorStatisticsSection(operatorStats),
            const SizedBox(height: 20),

            // Technician Statistics
            _buildTechnicianStatisticsSection(technicianStats),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
    // Helper to get unique operators by matricule
    List<Operator> uniqueOperators = [];
    final operatorMatricules = <String>{};
    for (var op in _operators) {
      if (!operatorMatricules.contains(op.matricule)) {
        operatorMatricules.add(op.matricule);
        uniqueOperators.add(op);
      }
    }

    // Helper to get unique technicians by matricule
    List<Technician> uniqueTechnicians = [];
    final technicianMatricules = <String>{};
    for (var tech in _technicians) {
      if (!technicianMatricules.contains(tech.matricule)) {
        technicianMatricules.add(tech.matricule);
        uniqueTechnicians.add(tech);
      }
    }

    // Reset selectedOperatorId if not in uniqueOperators
    if (_selectedOperatorId != null &&
        !operatorMatricules.contains(_selectedOperatorId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedOperatorId = null;
        });
      });
    }

    // Reset selectedTechnicianId if not in uniqueTechnicians
    if (_selectedTechnicianId != null &&
        !technicianMatricules.contains(_selectedTechnicianId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedTechnicianId = null;
        });
      });
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Time Period'),
                      DropdownButtonFormField<TimePeriod>(
                        value: _selectedTimePeriod,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.zero,
                        ),
                        isDense: true,
                        items: TimePeriod.values.map((period) {
                          return DropdownMenuItem<TimePeriod>(
                            value: period,
                            child: Text(period.name.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedTimePeriod = value!;
                            // Reset date inputs on time period change
                            _selectedDay = null;
                            _selectedMonth = null;
                            _selectedYear = null;
                            _weekStartDate = null;
                            _weekEndDate = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Machine'),
                      DropdownButtonFormField<String>(
                        value: _selectedMachineId,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.zero,
                        ),
                        isDense: true,
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text('All Machines'),
                          ),
                          ..._machines.map((machine) {
                            return DropdownMenuItem<String>(
                              value: machine.id,
                              child: Text(machine.name),
                            );
                          }).toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedMachineId = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedTimePeriod == TimePeriod.day)
                      _buildDatePicker(
                        label: 'Select Date',
                        selectedDate: _selectedDay,
                        onDateSelected: (date) {
                          setState(() {
                            _selectedDay = date;
                          });
                        },
                      ),
                    if (_selectedTimePeriod == TimePeriod.month)
                      _buildMonthPicker(
                        label: 'Select Month',
                        selectedDate: _selectedMonth,
                        onDateSelected: (date) {
                          setState(() {
                            _selectedMonth = date;
                          });
                        },
                      ),
                    if (_selectedTimePeriod == TimePeriod.year)
                      _buildYearPicker(
                        label: 'Select Year',
                        selectedYear: _selectedYear,
                        onYearSelected: (year) {
                          setState(() {
                            _selectedYear = year;
                          });
                        },
                      ),
                    if (_selectedTimePeriod == TimePeriod.week)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDatePicker(
                            label: 'Week Start Date',
                            selectedDate: _weekStartDate,
                            onDateSelected: (date) {
                              setState(() {
                                _weekStartDate = date;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          _buildDatePicker(
                            label: 'Week End Date',
                            selectedDate: _weekEndDate,
                            onDateSelected: (date) {
                              setState(() {
                                _weekEndDate = date;
                              });
                            },
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Operator'),
                        DropdownButtonFormField<String>(
                          value: _selectedOperatorId,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                          ),
                          isDense: true,
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text('All Operators'),
                            ),
                            ...uniqueOperators.map((operator) {
                              return DropdownMenuItem<String>(
                                value: operator.matricule,
                                child: Text(operator.name),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedOperatorId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        const Text('Technician'),
                        DropdownButtonFormField<String>(
                          value: _selectedTechnicianId,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                          ),
                          isDense: true,
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text('All Technicians'),
                            ),
                            ...uniqueTechnicians.map((technician) {
                              return DropdownMenuItem<String>(
                                value: technician.matricule,
                                child: Text(technician.name),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedTechnicianId = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper widgets for date/month/year pickers
  Widget _buildDatePicker({
    required String label,
    required DateTime? selectedDate,
    required ValueChanged<DateTime> onDateSelected,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          onDateSelected(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        child: Text(
          selectedDate != null
              ? '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}'
              : 'Select date',
          style: TextStyle(
            color: selectedDate != null ? Colors.black87 : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthPicker({
    required String label,
    required DateTime? selectedDate,
    required ValueChanged<DateTime> onDateSelected,
  }) {
    // Since Flutter does not have a built-in month picker, we use a date picker and ignore the day
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          selectableDayPredicate: (day) =>
              true, // Allow all days to be selectable
        );
        if (picked != null) {
          // Normalize to first day of the month
          onDateSelected(DateTime(picked.year, picked.month, 1));
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        child: Text(
          selectedDate != null
              ? '${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}'
              : 'Select month',
          style: TextStyle(
            color: selectedDate != null ? Colors.black87 : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildYearPicker({
    required String label,
    required int? selectedYear,
    required ValueChanged<int> onYearSelected,
  }) {
    return InkWell(
      onTap: () async {
        final years = List.generate(101, (index) => 2000 + index);
        final selected = await showDialog<int>(
          context: context,
          builder: (context) {
            return SimpleDialog(
              title: Text(label),
              children: years
                  .map(
                    (year) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, year),
                      child: Text(year.toString()),
                    ),
                  )
                  .toList(),
            );
          },
        );
        if (selected != null) {
          onYearSelected(selected);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
        child: Text(
          selectedYear?.toString() ?? 'Select year',
          style: TextStyle(
            color: selectedYear != null ? Colors.black87 : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildMachineStatisticsSection(MachineAnalytics analytics) {
    // Calculate filtered total working time and stopped time based on selected time period and filters
    Duration filteredWorkingTime = Duration.zero;
    Duration filteredStoppedTime = Duration.zero;
    Duration filteredMaintenanceTime = Duration.zero;
    Duration filteredStoppedWithoutMaintenance = Duration.zero;
    Duration filteredStoppedReadyForWork = Duration.zero;
    int filteredTotalSessions = 0;

    // Determine start and end date based on selected time period and inputs
    DateTime? startDate;
    DateTime? endDate;

    switch (_selectedTimePeriod) {
      case TimePeriod.day:
        if (_selectedDay != null) {
          startDate = DateTime(
            _selectedDay!.year,
            _selectedDay!.month,
            _selectedDay!.day,
          );
          endDate = startDate.add(const Duration(days: 1));
        }
        break;
      case TimePeriod.week:
        if (_weekStartDate != null && _weekEndDate != null) {
          startDate = DateTime(
            _weekStartDate!.year,
            _weekStartDate!.month,
            _weekStartDate!.day,
          );
          endDate = DateTime(
            _weekEndDate!.year,
            _weekEndDate!.month,
            _weekEndDate!.day,
          ).add(const Duration(days: 1));
        }
        break;
      case TimePeriod.month:
        if (_selectedMonth != null) {
          startDate = DateTime(_selectedMonth!.year, _selectedMonth!.month, 1);
          endDate = DateTime(
            _selectedMonth!.year,
            _selectedMonth!.month + 1,
            1,
          );
        }
        break;
      case TimePeriod.year:
        if (_selectedYear != null) {
          startDate = DateTime(_selectedYear!, 1, 1);
          endDate = DateTime(_selectedYear! + 1, 1, 1);
        }
        break;
      case TimePeriod.all:
        startDate = null;
        endDate = null;
        break;
    }

    // If no specific time period selected (e.g., user wants global stats), use null to indicate no filtering
    if (startDate == null || endDate == null) {
      filteredWorkingTime = analytics.totalWorkingTime;
      filteredStoppedTime = analytics.totalStoppedTime;

      // For maintenance and stopped without maintenance, sum over all machines if no specific machine selected
      if (_selectedMachineId == null) {
        filteredMaintenanceTime = _machineAnalytics.values.fold(
          Duration.zero,
          (prev, element) => prev + element.maintenanceInProgressTime,
        );
        filteredStoppedWithoutMaintenance = _machineAnalytics.values.fold(
          Duration.zero,
          (prev, element) => prev + element.stoppedWithoutMaintenanceTime,
        );
        filteredStoppedReadyForWork = _machineAnalytics.values.fold(
          Duration.zero,
          (prev, element) => prev + element.stoppedReadyForWorkTime,
        );
      } else {
        filteredMaintenanceTime = analytics.maintenanceInProgressTime;
        filteredStoppedWithoutMaintenance =
            analytics.stoppedWithoutMaintenanceTime;
        filteredStoppedReadyForWork = analytics.stoppedReadyForWorkTime;
      }

      // Filter sessions by machine if selected, else all sessions
      filteredTotalSessions = _sessions.where((session) {
        if (_selectedMachineId == null) return true;
        return session.machineReference == _selectedMachineId;
      }).length;
    } else {
      // Filter sessions by date and machine
      final filteredSessions = _sessions.where((session) {
        final sessionStart = session.startTime;
        return sessionStart.isAfter(startDate!) &&
            sessionStart.isBefore(endDate!) &&
            (_selectedMachineId == null ||
                session.machineReference == _selectedMachineId);
      }).toList();

      filteredTotalSessions = filteredSessions.length;

      // Sum durations from filtered sessions for working and stopped times
      for (final session in filteredSessions) {
        final analyticsForMachine = _machineAnalytics[session.machineReference];
        if (analyticsForMachine != null) {
          filteredWorkingTime += analyticsForMachine.totalWorkingTime;
          filteredStoppedTime += analyticsForMachine.totalStoppedTime;
          filteredMaintenanceTime +=
              analyticsForMachine.maintenanceInProgressTime;
          filteredStoppedWithoutMaintenance +=
              analyticsForMachine.stoppedWithoutMaintenanceTime;
          filteredStoppedReadyForWork +=
              analyticsForMachine.stoppedReadyForWorkTime;
        }
      }
    }

    final totalTime = filteredWorkingTime + filteredStoppedTime;
    final workingPercentage = totalTime.inSeconds > 0
        ? (filteredWorkingTime.inSeconds / totalTime.inSeconds * 100)
        : 0;
    final stoppedPercentage = totalTime.inSeconds > 0
        ? (filteredStoppedTime.inSeconds / totalTime.inSeconds * 100)
        : 0;

    // Prepare data source based on toggle state
    List<ChartData> chartData;
    if (_showPercentage) {
      final totalSeconds = totalTime.inSeconds > 0 ? totalTime.inSeconds : 1;
      chartData = [
        ChartData(
          'Working',
          (filteredWorkingTime.inSeconds / totalSeconds * 100),
          Colors.green,
        ),
        ChartData(
          'Stopped',
          (filteredStoppedTime.inSeconds / totalSeconds * 100),
          Colors.orange,
        ),
        ChartData(
          'Maintenance',
          (filteredMaintenanceTime.inSeconds / totalSeconds * 100),
          Colors.blue,
        ),
        ChartData(
          'Stopped (No Maintenance)',
          (filteredStoppedWithoutMaintenance.inSeconds / totalSeconds * 100),
          Colors.red,
        ),
        ChartData(
          'Stopped Ready For Work',
          (filteredStoppedReadyForWork.inSeconds / totalSeconds * 100),
          Colors.purple,
        ),
      ];
    } else {
      double toHours(Duration d) => d.inSeconds / 3600.0;
      chartData = [
        ChartData('Working', toHours(filteredWorkingTime), Colors.green),
        ChartData('Stopped', toHours(filteredStoppedTime), Colors.orange),
        ChartData('Maintenance', toHours(filteredMaintenanceTime), Colors.blue),
        ChartData(
          'Stopped (No Maintenance)',
          toHours(filteredStoppedWithoutMaintenance),
          Colors.red,
        ),
        ChartData(
          'Stopped Ready For Work',
          toHours(filteredStoppedReadyForWork),
          Colors.purple,
        ),
      ];
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Machine Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // ToggleButtons for Time/Percentage
            ToggleButtons(
              isSelected: [_showPercentage == false, _showPercentage == true],
              onPressed: (index) {
                setState(() {
                  _showPercentage = index == 1;
                });
              },
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Time'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Percentage'),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Machine Time Pie Chart
            SizedBox(
              height: 300,
              child: SfCircularChart(
                title: ChartTitle(
                  text:
                      'Machine Time Distribution' +
                      (_showPercentage ? ' (Percentage)' : ' (Time)'),
                ),
                legend: Legend(isVisible: true),
                series: <CircularSeries<ChartData, String>>[
                  PieSeries<ChartData, String>(
                    dataSource: chartData,
                    xValueMapper: (ChartData data, _) => data.category,
                    yValueMapper: (ChartData data, _) => data.value,
                    pointColorMapper: (ChartData data, _) => data.color,
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                    dataLabelMapper: (ChartData data, _) => _showPercentage
                        ? '${data.value.toStringAsFixed(1)}%'
                        : (() {
                            if (data.category == 'Working') {
                              return _formatDuration(filteredWorkingTime);
                            } else if (data.category == 'Stopped') {
                              return _formatDuration(filteredStoppedTime);
                            } else if (data.category == 'Maintenance') {
                              return _formatDuration(filteredMaintenanceTime);
                            } else if (data.category ==
                                'Stopped (No Maintenance)') {
                              return _formatDuration(
                                filteredStoppedWithoutMaintenance,
                              );
                            } else if (data.category ==
                                'Stopped Ready For Work') {
                              return _formatDuration(
                                filteredStoppedReadyForWork,
                              );
                            } else {
                              return '';
                            }
                          })(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),
            _buildStatCard(
              'Total Working Time',
              _formatDuration(filteredWorkingTime),
            ),
            _buildStatCard(
              'Total Stopped Time',
              _formatDuration(filteredStoppedTime),
            ),
            _buildStatCard(
              'Maintenance In Progress',
              _formatDuration(filteredMaintenanceTime),
            ),
            _buildStatCard(
              'Stopped Without Maintenance',
              _formatDuration(filteredStoppedWithoutMaintenance),
            ),
            _buildStatCard(
              'Stopped Ready For Work',
              _formatDuration(filteredStoppedReadyForWork),
            ),
            _buildStatCard('Total Sessions', filteredTotalSessions.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildOperatorStatisticsSection(Map<String, dynamic> stats) {
    // Fix filter: if _selectedOperatorId is null, show all operators
    // Aggregate operator working time accordingly

    // Helper: format duration to string
    String formatDuration(Duration d) {
      if (d.inHours > 0) {
        return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
      } else if (d.inMinutes > 0) {
        return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
      } else {
        return '${d.inSeconds}s';
      }
    }

    // Aggregate operator working time based on selected time period
    if (_selectedTimePeriod == TimePeriod.all) {
      // Show pie chart of total working time per operator
      final operatorTime = stats['operatorTime'] as Map<String, Duration>;
      final pieData = operatorTime.entries.map((e) {
        final operator = _operators.firstWhere(
          (op) => op.matricule == e.key,
          orElse: () => Operator(matricule: e.key, name: 'Unknown'),
        );
        // Use fractional hours with minutes and seconds converted to fraction
        double hours = e.value.inSeconds / 3600.0;
        return ChartData(operator.name, hours, Colors.blue);
      }).toList();

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Operator Statistics (Pie Chart)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (pieData.isNotEmpty)
                SizedBox(
                  height: 300,
                  child: SfCircularChart(
                    title: ChartTitle(
                      text: 'Operator Working Time Distribution',
                    ),
                    legend: Legend(isVisible: true),
                    series: <CircularSeries<ChartData, String>>[
                      PieSeries<ChartData, String>(
                        dataSource: pieData,
                        xValueMapper: (ChartData data, _) => data.category,
                        yValueMapper: (ChartData data, _) => data.value,
                        dataLabelSettings: const DataLabelSettings(
                          isVisible: true,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              ...operatorTime.entries.map((entry) {
                final operator = _operators.firstWhere(
                  (op) => op.matricule == entry.key,
                  orElse: () => Operator(matricule: entry.key, name: 'Unknown'),
                );
                return _buildStatCard(
                  '${operator.name} Working Time',
                  formatDuration(entry.value),
                );
              }).toList(),
              _buildStatCard(
                'Total Operator Sessions',
                stats['totalOperatorSessions'].toString(),
              ),
            ],
          ),
        ),
      );
    } else if (_selectedTimePeriod == TimePeriod.day) {
      // Show bar chart with 24 hours on horizontal axis
      // Aggregate operator working time by hour for the selected day

      // Prepare data: Map operator name -> List<double> of 24 hours working time in hours
      final operatorTime = stats['operatorTime'] as Map<String, Duration>;
      // We need to aggregate sessions by hour for each operator for the selected day
      // So we will build a map: operator matricule -> List<double> (24 length)
      Map<String, List<double>> operatorHourlyData = {};

      // Initialize with zeros
      for (var op in _operators) {
        operatorHourlyData[op.matricule] = List.filled(24, 0.0);
      }

      // Aggregate sessions by hour for selected day
      DateTime dayStart = _selectedDay ?? DateTime.now();
      DateTime dayEnd = dayStart.add(const Duration(days: 1));

      for (var session in _sessions) {
        if (session.endTime == null) continue;
        // Check if session overlaps with the selected day
        if (session.startTime.isBefore(dayEnd) &&
            session.endTime!.isAfter(dayStart)) {
          if (_selectedOperatorId == null ||
              session.operatorMatricule == _selectedOperatorId) {
            // Calculate overlap of session with each hour in the day
            DateTime sessionStart = session.startTime.isBefore(dayStart)
                ? dayStart
                : session.startTime;
            DateTime sessionEnd = session.endTime!.isAfter(dayEnd)
                ? dayEnd
                : session.endTime!;
            for (int hour = 0; hour < 24; hour++) {
              DateTime hourStart = DateTime(
                dayStart.year,
                dayStart.month,
                dayStart.day,
                hour,
              );
              DateTime hourEnd = hourStart.add(const Duration(hours: 1));
              DateTime overlapStart = sessionStart.isAfter(hourStart)
                  ? sessionStart
                  : hourStart;
              DateTime overlapEnd = sessionEnd.isBefore(hourEnd)
                  ? sessionEnd
                  : hourEnd;
              if (overlapEnd.isAfter(overlapStart)) {
                Duration overlapDuration = overlapEnd.difference(overlapStart);
                double hours = overlapDuration.inSeconds / 3600.0;
                operatorHourlyData[session.operatorMatricule]?[hour] += hours;
              }
            }
          }
        }
      }

      // Prepare chart data: For each operator, create a series of 24 data points
      List<CartesianSeries<OperatorHourlyData, String>> seriesList = [];
      for (var op in _operators) {
        if (_selectedOperatorId != null && op.matricule != _selectedOperatorId)
          continue;
        List<OperatorHourlyData> data = [];
        for (int h = 0; h < 24; h++) {
          data.add(
            OperatorHourlyData(
              h.toString(),
              operatorHourlyData[op.matricule]?[h] ?? 0.0,
            ),
          );
        }
        seriesList.add(
          StackedColumnSeries<OperatorHourlyData, String>(
            dataSource: data,
            xValueMapper: (OperatorHourlyData d, _) => d.hour,
            yValueMapper: (OperatorHourlyData d, _) => d.hours,
            name: op.name,
            dataLabelSettings: const DataLabelSettings(isVisible: false),
          ),
        );
      }

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Operator Statistics (Hourly Bar Chart)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 300,
                child: SfCartesianChart(
                  title: ChartTitle(text: 'Operator Working Time by Hour'),
                  primaryXAxis: CategoryAxis(
                    title: AxisTitle(text: 'Hour of Day'),
                    interval: 1,
                  ),
                  primaryYAxis: NumericAxis(
                    title: AxisTitle(text: 'Hours'),
                    minimum: 0,
                  ),
                  legend: Legend(isVisible: true),
                  series: seriesList,
                ),
              ),
              _buildStatCard(
                'Total Operator Sessions',
                stats['totalOperatorSessions'].toString(),
              ),
            ],
          ),
        ),
      );
    } else if (_selectedTimePeriod == TimePeriod.year) {
      // Show calendar with hover tooltips for total working time per date

      // Aggregate working time per date for the selected year
      int year = _selectedYear ?? DateTime.now().year;
      Map<String, Duration> workingTimePerDate = {};

      String formatDateKey(DateTime date) {
        return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }

      for (var session in _sessions) {
        if (session.startTime.year == year && session.endTime != null) {
          String dateKey = formatDateKey(
            DateTime(
              session.startTime.year,
              session.startTime.month,
              session.startTime.day,
            ),
          );
          if (_selectedOperatorId == null ||
              session.operatorMatricule == _selectedOperatorId) {
            Duration duration = session.endTime!.difference(session.startTime);
            workingTimePerDate.update(
              dateKey,
              (existing) => existing + duration,
              ifAbsent: () => duration,
            );
          }
        }
      }

      // Calculate initial scroll offset to focus on today's date if operator selected
      final today = DateTime.now();
      final daysFromYearStart = today.difference(DateTime(year)).inDays;
      final scrollToIndex =
          (_selectedOperatorId != null &&
              daysFromYearStart >= 0 &&
              daysFromYearStart < 365)
          ? daysFromYearStart
          : 0;

      final ScrollController scrollController = ScrollController(
        initialScrollOffset:
            scrollToIndex * 50.0, // Approximate item height + spacing
      );

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Operator Statistics (Yearly Calendar)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 400,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_left),
                          onPressed: () {
                            setState(() {
                              _selectedYear = (_selectedYear ?? year) - 1;
                            });
                          },
                        ),
                        Text(
                          'Year: ${_selectedYear ?? year}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_right),
                          onPressed: () {
                            setState(() {
                              _selectedYear = (_selectedYear ?? year) + 1;
                            });
                          },
                        ),
                      ],
                    ),
                    Expanded(
                      child: GridView.builder(
                        controller: scrollController,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7, // 7 days per week
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                              childAspectRatio: 1,
                            ),
                        itemCount: 365,
                        itemBuilder: (context, index) {
                          DateTime date = DateTime(
                            year,
                          ).add(Duration(days: index));
                          String dateKey = formatDateKey(date);
                          Duration workingTime =
                              workingTimePerDate[dateKey] ?? Duration.zero;
                          String tooltip = workingTime > Duration.zero
                              ? 'Working Time: ${formatDuration(workingTime)}'
                              : 'No Work';

                          return Tooltip(
                            message:
                                '${date.day}/${date.month}/$year\n$tooltip',
                            child: Container(
                              decoration: BoxDecoration(
                                color: workingTime > Duration.zero
                                    ? Colors.green.shade300
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                date.day.toString(),
                                style: TextStyle(
                                  color: workingTime > Duration.zero
                                      ? Colors.black
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatCard(
                'Total Operator Sessions',
                stats['totalOperatorSessions'].toString(),
              ),
            ],
          ),
        ),
      );
    } else {
      // Default: show bar chart as before for other time periods
      final operatorTime = stats['operatorTime'] as Map<String, Duration>;

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Operator Statistics',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              // Operator Time Bar Chart
              if (operatorTime.isNotEmpty)
                SizedBox(
                  height: 300,
                  child: SfCartesianChart(
                    title: ChartTitle(text: 'Operator Working Time'),
                    primaryXAxis: CategoryAxis(),
                    primaryYAxis: NumericAxis(title: AxisTitle(text: 'Hours')),
                    series: <CartesianSeries<OperatorTimeData, String>>[
                      BarSeries<OperatorTimeData, String>(
                        dataSource: operatorTime.entries.map((e) {
                          final operator = _operators.firstWhere(
                            (op) => op.matricule == e.key,
                            orElse: () =>
                                Operator(matricule: e.key, name: 'Unknown'),
                          );
                          // Use fractional hours instead of integer hours
                          double hours = e.value.inSeconds / 3600.0;
                          return OperatorTimeData(operator.name, hours);
                        }).toList(),
                        xValueMapper: (OperatorTimeData data, _) =>
                            data.operatorName,
                        yValueMapper: (OperatorTimeData data, _) => data.hours,
                        dataLabelSettings: const DataLabelSettings(
                          isVisible: true,
                        ),
                        dataLabelMapper: (OperatorTimeData data, _) =>
                            '${data.hours.toStringAsFixed(1)}h',
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 10),
              ...operatorTime.entries.map((entry) {
                final operator = _operators.firstWhere(
                  (op) => op.matricule == entry.key,
                  orElse: () => Operator(matricule: entry.key, name: 'Unknown'),
                );
                return _buildStatCard(
                  '${operator.name} Working Time',
                  formatDuration(entry.value),
                );
              }).toList(),

              _buildStatCard(
                'Total Operator Sessions',
                stats['totalOperatorSessions'].toString(),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildTechnicianStatisticsSection(Map<String, dynamic> stats) {
    final responseTimes = stats['responseTimes'] as Map<String, List<Duration>>;
    final repairTimes = stats['repairTimes'] as Map<String, List<Duration>>;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Technician Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Technician Performance Charts
            if (responseTimes.isNotEmpty)
              Column(
                children: [
                  SizedBox(
                    height: 300,
                    child: SfCartesianChart(
                      title: ChartTitle(
                        text: 'Average Response Time (Minutes)',
                      ),
                      primaryXAxis: CategoryAxis(),
                      primaryYAxis: NumericAxis(
                        title: AxisTitle(text: 'Minutes'),
                      ),
                      series:
                          <CartesianSeries<TechnicianPerformanceData, String>>[
                            BarSeries<TechnicianPerformanceData, String>(
                              dataSource: responseTimes.entries.map((e) {
                                final tech = _technicians.firstWhere(
                                  (t) => t.matricule == e.key,
                                  orElse: () => Technician(
                                    matricule: e.key,
                                    name: 'Unknown',
                                  ),
                                );
                                final avgResponse =
                                    e.value.fold(
                                      Duration.zero,
                                      (sum, d) => sum + d,
                                    ) ~/
                                    e.value.length;
                                return TechnicianPerformanceData(
                                  tech.name,
                                  avgResponse.inMinutes.toDouble(),
                                );
                              }).toList(),
                              xValueMapper:
                                  (TechnicianPerformanceData data, _) =>
                                      data.technicianName,
                              yValueMapper:
                                  (TechnicianPerformanceData data, _) =>
                                      data.value,
                              dataLabelSettings: const DataLabelSettings(
                                isVisible: true,
                              ),
                            ),
                          ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    height: 300,
                    child: SfCartesianChart(
                      title: ChartTitle(text: 'Average Repair Time (Hours)'),
                      primaryXAxis: CategoryAxis(),
                      primaryYAxis: NumericAxis(
                        title: AxisTitle(text: 'Hours'),
                      ),
                      series:
                          <CartesianSeries<TechnicianPerformanceData, String>>[
                            BarSeries<TechnicianPerformanceData, String>(
                              dataSource: repairTimes.entries.map((e) {
                                final tech = _technicians.firstWhere(
                                  (t) => t.matricule == e.key,
                                  orElse: () => Technician(
                                    matricule: e.key,
                                    name: 'Unknown',
                                  ),
                                );
                                final avgRepair =
                                    e.value.fold(
                                      Duration.zero,
                                      (sum, d) => sum + d,
                                    ) ~/
                                    e.value.length;
                                return TechnicianPerformanceData(
                                  tech.name,
                                  avgRepair.inHours.toDouble(),
                                );
                              }).toList(),
                              xValueMapper:
                                  (TechnicianPerformanceData data, _) =>
                                      data.technicianName,
                              yValueMapper:
                                  (TechnicianPerformanceData data, _) =>
                                      data.value,
                              dataLabelSettings: const DataLabelSettings(
                                isVisible: true,
                              ),
                            ),
                          ],
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 10),
            ...responseTimes.entries.map((entry) {
              final tech = _technicians.firstWhere(
                (t) => t.matricule == entry.key,
                orElse: () => Technician(matricule: entry.key, name: 'Unknown'),
              );
              final avgResponse =
                  entry.value.fold(Duration.zero, (sum, d) => sum + d) ~/
                  entry.value.length;
              return _buildStatCard(
                '${tech.name} Avg Response',
                _formatDuration(avgResponse),
              );
            }).toList(),

            ...repairTimes.entries.map((entry) {
              final tech = _technicians.firstWhere(
                (t) => t.matricule == entry.key,
                orElse: () => Technician(matricule: entry.key, name: 'Unknown'),
              );
              final avgRepair =
                  entry.value.fold(Duration.zero, (sum, d) => sum + d) ~/
                  entry.value.length;
              return _buildStatCard(
                '${tech.name} Avg Repair',
                _formatDuration(avgRepair),
              );
            }).toList(),

            _buildStatCard(
              'Total Technician Issues',
              stats['totalTechnicianIssues'].toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}

enum TimePeriod { all, day, week, month, year }

extension TimePeriodExtension on TimePeriod {
  String get name {
    switch (this) {
      case TimePeriod.all:
        return 'all';
      case TimePeriod.day:
        return 'day';
      case TimePeriod.week:
        return 'week';
      case TimePeriod.month:
        return 'month';
      case TimePeriod.year:
        return 'year';
    }
  }
}
