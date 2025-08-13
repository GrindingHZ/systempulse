class PerformanceData {
  final DateTime timestamp;
  final double cpuUsage;
  final double memoryUsage;
  final double memoryUsedMB;
  final double memoryTotalMB;
  final double batteryLevel;
  final double batteryTemperature;
  final String batteryStatus;
  final bool isCharging;

  const PerformanceData({
    required this.timestamp,
    required this.cpuUsage,
    required this.memoryUsage,
    required this.memoryUsedMB,
    required this.memoryTotalMB,
    required this.batteryLevel,
    required this.batteryTemperature,
    required this.batteryStatus,
    required this.isCharging,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'cpuUsage': cpuUsage,
      'memoryUsage': memoryUsage,
      'memoryUsedMB': memoryUsedMB,
      'memoryTotalMB': memoryTotalMB,
      'batteryLevel': batteryLevel,
      'batteryTemperature': batteryTemperature,
      'batteryStatus': batteryStatus,
      'isCharging': isCharging,
    };
  }

  factory PerformanceData.fromJson(Map<String, dynamic> json) {
    return PerformanceData(
      timestamp: DateTime.parse(json['timestamp']),
      cpuUsage: json['cpuUsage'].toDouble(),
      memoryUsage: json['memoryUsage'].toDouble(),
      memoryUsedMB: json['memoryUsedMB'].toDouble(),
      memoryTotalMB: json['memoryTotalMB'].toDouble(),
      batteryLevel: json['batteryLevel']?.toDouble() ?? 0.0,
      batteryTemperature: json['batteryTemperature']?.toDouble() ?? 0.0,
      batteryStatus: json['batteryStatus']?.toString() ?? 'Unknown',
      isCharging: json['isCharging'] ?? false,
    );
  }

  List<String> toCsvRow() {
    return [
      timestamp.toIso8601String(),
      cpuUsage.toStringAsFixed(2),
      memoryUsage.toStringAsFixed(2),
      memoryUsedMB.toStringAsFixed(2),
      memoryTotalMB.toStringAsFixed(2),
      batteryLevel.toStringAsFixed(1),
      batteryTemperature.toStringAsFixed(1),
      batteryStatus,
      isCharging ? 'Yes' : 'No',
    ];
  }

  static List<String> get csvHeaders => [
    'Timestamp',
    'CPU Usage (%)',
    'Memory Usage (%)',
    'Memory Used (MB)',
    'Memory Total (MB)',
    'Battery Level (%)',
    'Battery Temperature (°C)',
    'Battery Status',
    'Is Charging',
  ];
}
