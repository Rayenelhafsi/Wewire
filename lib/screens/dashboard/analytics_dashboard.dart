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

  @override
  void initState() {
    super.initState();
    _setupStreamListeners();
  }

  @override
  void dispose() {
    _machinesSubscription?.cancel();
    _operatorsSubscription?.cancel();
    _techniciansSubscription?.cancel();
    _sessionsSubscription?.cancel();
    _issuesSubscription?.cancel();
    super.dispose();
  }

  void _setupStreamListeners() {
    _machinesSubscription = FirebaseService.getMachines().listen((machines) {
      setState(() {
        _machines = machines;
      });

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
    }
  }

  // Machine Statistics Calculations
  Map<String, dynamic> _calculateMachineStatistics() {
    final startDate = _getStartDateForPeriod(_selectedTimePeriod);
    final filteredSessions = _sessions
        .where(
          (session) =>
              session.startTime.isAfter(startDate) &&
              (_selectedMachineId == null ||
                  session.machineReference == _selectedMachineId),
        )
        .toList();

    // Filter issues for potential future use
    _issues.where(
      (issue) =>
          issue.createdAt.isAfter(startDate) &&
          (_selectedMachineId == null || issue.machineId == _selectedMachineId),
    );

    // Calculate total working time (both in-progress and closed sessions)
    final totalWorkingTime = filteredSessions
        .where(
          (session) =>
              session.status == SessionStatus.inProgress ||
              session.status == SessionStatus.closed,
        )
        .fold(Duration.zero, (total, session) {
          if (session.status == SessionStatus.inProgress) {
            // For in-progress sessions, calculate time from start to now
            return total + (DateTime.now().difference(session.startTime));
          } else {
            // For closed sessions, calculate time from start to end
            return total +
                (session.endTime?.difference(session.startTime) ??
                    Duration.zero);
          }
        });

    // Calculate total stopped time (open sessions without maintenance)
    final totalStoppedTime = filteredSessions
        .where((session) => session.status == SessionStatus.open)
        .fold(
          Duration.zero,
          (total, session) =>
              total + (DateTime.now().difference(session.startTime)),
        );

    // Calculate maintenance in progress time (in-progress sessions)
    final maintenanceInProgressTime = filteredSessions
        .where((session) => session.status == SessionStatus.inProgress)
        .fold(
          Duration.zero,
          (total, session) =>
              total + (DateTime.now().difference(session.startTime)),
        );

    // Calculate stopped without maintenance time (open sessions)
    final stoppedWithoutMaintenance = filteredSessions
        .where((session) => session.status == SessionStatus.open)
        .fold(
          Duration.zero,
          (total, session) =>
              total + (DateTime.now().difference(session.startTime)),
        );

    return {
      'totalWorkingTime': totalWorkingTime,
      'totalStoppedTime': totalStoppedTime,
      'maintenanceInProgressTime': maintenanceInProgressTime,
      'stoppedWithoutMaintenance': stoppedWithoutMaintenance,
      'totalSessions': filteredSessions.length,
    };
  }

  // Operator Statistics Calculations
  Map<String, dynamic> _calculateOperatorStatistics() {
    final startDate = _getStartDateForPeriod(_selectedTimePeriod);
    final filteredSessions = _sessions
        .where(
          (session) =>
              session.startTime.isAfter(startDate) &&
              (_selectedOperatorId == null ||
                  session.operatorMatricule == _selectedOperatorId) &&
              (_selectedMachineId == null ||
                  session.machineReference == _selectedMachineId),
        )
        .toList();

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
    final startDate = _getStartDateForPeriod(_selectedTimePeriod);
    final filteredIssues = _issues
        .where(
          (issue) =>
              issue.createdAt.isAfter(startDate) &&
              (_selectedTechnicianId == null ||
                  issue.assignedMaintenanceId == _selectedTechnicianId),
        )
        .toList();

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

  @override
  Widget build(BuildContext context) {
    final machineStats = _calculateMachineStatistics();
    final operatorStats = _calculateOperatorStatistics();
    final technicianStats = _calculateTechnicianStatistics();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        actions: [
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
            _buildMachineStatisticsSection(machineStats),
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
                          const DropdownMenuItem(
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
                final isNarrow = constraints.maxWidth < 400;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    isNarrow
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Operator'),
                              DropdownButtonFormField<String>(
                                value: _selectedOperatorId,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                  ),
                                ),
                                isDense: true,
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('All Operators'),
                                  ),
                                  ..._operators.map((operator) {
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
                                    horizontal: 8.0,
                                  ),
                                ),
                                isDense: true,
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('All Technicians'),
                                  ),
                                  ..._technicians.map((technician) {
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
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Operator'),
                                    DropdownButtonFormField<String>(
                                      value: _selectedOperatorId,
                                      decoration: const InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8.0,
                                        ),
                                      ),
                                      isDense: true,
                                      items: [
                                        const DropdownMenuItem(
                                          value: null,
                                          child: Text('All Operators'),
                                        ),
                                        ..._operators.map((operator) {
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
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Technician'),
                                    DropdownButtonFormField<String>(
                                      value: _selectedTechnicianId,
                                      decoration: const InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8.0,
                                        ),
                                      ),
                                      isDense: true,
                                      items: [
                                        const DropdownMenuItem(
                                          value: null,
                                          child: Text('All Technicians'),
                                        ),
                                        ..._technicians.map((technician) {
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

  Widget _buildMachineStatisticsSection(Map<String, dynamic> stats) {
    final totalWorkingTime = stats['totalWorkingTime'] as Duration;
    final totalStoppedTime = stats['totalStoppedTime'] as Duration;
    final maintenanceTime = stats['maintenanceInProgressTime'] as Duration;
    final stoppedWithoutMaintenance =
        stats['stoppedWithoutMaintenance'] as Duration;

    final totalTime = totalWorkingTime + totalStoppedTime;
    final workingPercentage = totalTime.inSeconds > 0
        ? (totalWorkingTime.inSeconds / totalTime.inSeconds * 100)
        : 0;
    final stoppedPercentage = totalTime.inSeconds > 0
        ? (totalStoppedTime.inSeconds / totalTime.inSeconds * 100)
        : 0;

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

            // Machine Time Pie Chart
            SizedBox(
              height: 300,
              child: SfCircularChart(
                title: ChartTitle(text: 'Machine Time Distribution'),
                legend: Legend(isVisible: true),
                series: <CircularSeries<ChartData, String>>[
                  PieSeries<ChartData, String>(
                    dataSource: [
                      ChartData(
                        'Working',
                        workingPercentage.toDouble(),
                        Colors.green,
                      ),
                      ChartData(
                        'Stopped',
                        stoppedPercentage.toDouble(),
                        Colors.orange,
                      ),
                      ChartData(
                        'Maintenance',
                        maintenanceTime.inHours.toDouble(),
                        Colors.blue,
                      ),
                      ChartData(
                        'Stopped (No Maintenance)',
                        stoppedWithoutMaintenance.inHours.toDouble(),
                        Colors.red,
                      ),
                    ],
                    xValueMapper: (ChartData data, _) => data.category,
                    yValueMapper: (ChartData data, _) => data.value,
                    pointColorMapper: (ChartData data, _) => data.color,
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                    dataLabelMapper: (ChartData data, _) =>
                        '${data.value.toStringAsFixed(1)}%',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),
            _buildStatCard(
              'Total Working Time',
              _formatDuration(totalWorkingTime),
            ),
            _buildStatCard(
              'Total Stopped Time',
              _formatDuration(totalStoppedTime),
            ),
            _buildStatCard(
              'Maintenance In Progress',
              _formatDuration(maintenanceTime),
            ),
            _buildStatCard(
              'Stopped Without Maintenance',
              _formatDuration(stoppedWithoutMaintenance),
            ),
            _buildStatCard('Total Sessions', stats['totalSessions'].toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildOperatorStatisticsSection(Map<String, dynamic> stats) {
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
                        return OperatorTimeData(
                          operator.name,
                          e.value.inHours.toDouble(),
                        );
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
                _formatDuration(entry.value),
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

enum TimePeriod { day, week, month, year }

extension TimePeriodExtension on TimePeriod {
  String get name {
    switch (this) {
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
