import 'package:cpu_memory_tracking_app/models/performance_data.dart';

class RecordingSession {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final List<PerformanceData> dataPoints;
  final String? filePath;

  const RecordingSession({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.dataPoints,
    this.filePath,
  });

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  bool get isActive => endTime == null;

  bool get isAutoSaved => id.contains('_autosave_') || id.contains('_emergency_');

  double get averageCpuUsage {
    if (dataPoints.isEmpty) return 0.0;
    return dataPoints.map((e) => e.cpuUsage).reduce((a, b) => a + b) / dataPoints.length;
  }

  double get averageMemoryUsage {
    if (dataPoints.isEmpty) return 0.0;
    return dataPoints.map((e) => e.memoryUsage).reduce((a, b) => a + b) / dataPoints.length;
  }

  double get maxCpuUsage {
    if (dataPoints.isEmpty) return 0.0;
    return dataPoints.map((e) => e.cpuUsage).reduce((a, b) => a > b ? a : b);
  }

  double get maxMemoryUsage {
    if (dataPoints.isEmpty) return 0.0;
    return dataPoints.map((e) => e.memoryUsage).reduce((a, b) => a > b ? a : b);
  }

  double get averageBatteryLevel {
    if (dataPoints.isEmpty) return 0.0;
    return dataPoints.map((e) => e.batteryLevel).reduce((a, b) => a + b) / dataPoints.length;
  }

  double get minBatteryLevel {
    if (dataPoints.isEmpty) return 0.0;
    return dataPoints.map((e) => e.batteryLevel).reduce((a, b) => a < b ? a : b);
  }

  double get maxBatteryLevel {
    if (dataPoints.isEmpty) return 0.0;
    return dataPoints.map((e) => e.batteryLevel).reduce((a, b) => a > b ? a : b);
  }

  double get averageBatteryTemperature {
    if (dataPoints.isEmpty) return 0.0;
    return dataPoints.map((e) => e.batteryTemperature).reduce((a, b) => a + b) / dataPoints.length;
  }

  double get maxBatteryTemperature {
    if (dataPoints.isEmpty) return 0.0;
    return dataPoints.map((e) => e.batteryTemperature).reduce((a, b) => a > b ? a : b);
  }

  // Battery status at the end of recording
  String get finalBatteryStatus {
    if (dataPoints.isEmpty) return 'Unknown';
    return dataPoints.last.batteryStatus;
  }

  // Check if device was charging during most of the recording
  bool get wasChargingDuringRecording {
    if (dataPoints.isEmpty) return false;
    final chargingCount = dataPoints.where((e) => e.isCharging).length;
    return chargingCount > (dataPoints.length / 2);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'dataPoints': dataPoints.map((e) => e.toJson()).toList(),
      'filePath': filePath,
    };
  }

  factory RecordingSession.fromJson(Map<String, dynamic> json) {
    return RecordingSession(
      id: json['id'],
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      dataPoints: (json['dataPoints'] as List)
          .map((e) => PerformanceData.fromJson(e))
          .toList(),
      filePath: json['filePath'],
    );
  }

  RecordingSession copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    List<PerformanceData>? dataPoints,
    String? filePath,
  }) {
    return RecordingSession(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      dataPoints: dataPoints ?? this.dataPoints,
      filePath: filePath ?? this.filePath,
    );
  }
}
