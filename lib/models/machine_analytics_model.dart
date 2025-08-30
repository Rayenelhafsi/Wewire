class MachineAnalytics {
  final String machineId;
  final Map<String, Duration> dailyStoppedTime; // key: date string (yyyy-MM-dd)
  final Map<String, Duration> monthlyStoppedTime; // key: month string (yyyy-MM)
  final Map<String, Duration> yearlyStoppedTime; // key: year string (yyyy)
  final Duration totalWorkingTime;
  final Duration totalStoppedTime;
  final Duration stoppedWithoutMaintenanceTime;
  final Duration stoppedReadyForWorkTime;
  final Duration maintenanceInProgressTime;
  final DateTime lastUpdated;

  MachineAnalytics({
    required this.machineId,
    required this.dailyStoppedTime,
    required this.monthlyStoppedTime,
    required this.yearlyStoppedTime,
    required this.totalWorkingTime,
    required this.totalStoppedTime,
    required this.stoppedWithoutMaintenanceTime,
    required this.stoppedReadyForWorkTime,
    required this.maintenanceInProgressTime,
    required this.lastUpdated,
  });

  factory MachineAnalytics.fromJson(Map<String, dynamic> json) {
    return MachineAnalytics(
      machineId: json['machineId'] ?? '',
      dailyStoppedTime: _parseDurationMap(json['dailyStoppedTime'] ?? {}),
      monthlyStoppedTime: _parseDurationMap(json['monthlyStoppedTime'] ?? {}),
      yearlyStoppedTime: _parseDurationMap(json['yearlyStoppedTime'] ?? {}),
      totalWorkingTime: _parseDuration(json['totalWorkingTime']),
      totalStoppedTime: _parseDuration(json['totalStoppedTime']),
      stoppedWithoutMaintenanceTime: _parseDuration(
        json['stoppedWithoutMaintenanceTime'],
      ),
      stoppedReadyForWorkTime: _parseDuration(json['stoppedReadyForWorkTime']),
      maintenanceInProgressTime: _parseDuration(
        json['maintenanceInProgressTime'],
      ),
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'machineId': machineId,
      'dailyStoppedTime': durationMapToJson(dailyStoppedTime),
      'monthlyStoppedTime': durationMapToJson(monthlyStoppedTime),
      'yearlyStoppedTime': durationMapToJson(yearlyStoppedTime),
      'totalWorkingTime': totalWorkingTime.inSeconds,
      'totalStoppedTime': totalStoppedTime.inSeconds,
      'stoppedWithoutMaintenanceTime': stoppedWithoutMaintenanceTime.inSeconds,
      'stoppedReadyForWorkTime': stoppedReadyForWorkTime.inSeconds,
      'maintenanceInProgressTime': maintenanceInProgressTime.inSeconds,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  static Duration _parseDuration(dynamic value) {
    if (value is int) {
      return Duration(seconds: value);
    }
    return Duration.zero;
  }

  static Map<String, Duration> _parseDurationMap(Map<String, dynamic> map) {
    return map.map(
      (key, value) => MapEntry(key, Duration(seconds: value as int)),
    );
  }

  static Map<String, int> durationMapToJson(Map<String, Duration> map) {
    return map.map((key, value) => MapEntry(key, value.inSeconds));
  }

  // Helper method to update time statistics
  MachineAnalytics copyWith({
    Map<String, Duration>? dailyStoppedTime,
    Map<String, Duration>? monthlyStoppedTime,
    Map<String, Duration>? yearlyStoppedTime,
    Duration? totalWorkingTime,
    Duration? totalStoppedTime,
    Duration? stoppedWithoutMaintenanceTime,
    Duration? stoppedReadyForWorkTime,
    Duration? maintenanceInProgressTime,
    DateTime? lastUpdated,
  }) {
    return MachineAnalytics(
      machineId: machineId,
      dailyStoppedTime: dailyStoppedTime ?? this.dailyStoppedTime,
      monthlyStoppedTime: monthlyStoppedTime ?? this.monthlyStoppedTime,
      yearlyStoppedTime: yearlyStoppedTime ?? this.yearlyStoppedTime,
      totalWorkingTime: totalWorkingTime ?? this.totalWorkingTime,
      totalStoppedTime: totalStoppedTime ?? this.totalStoppedTime,
      stoppedWithoutMaintenanceTime:
          stoppedWithoutMaintenanceTime ?? this.stoppedWithoutMaintenanceTime,
      stoppedReadyForWorkTime:
          stoppedReadyForWorkTime ?? this.stoppedReadyForWorkTime,
      maintenanceInProgressTime:
          maintenanceInProgressTime ?? this.maintenanceInProgressTime,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
