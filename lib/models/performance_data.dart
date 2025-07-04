class PerformanceData {
  final DateTime timestamp;
  final double cpuUsage;
  final double memoryUsage;
  final double memoryUsedMB;
  final double memoryTotalMB;

  const PerformanceData({
    required this.timestamp,
    required this.cpuUsage,
    required this.memoryUsage,
    required this.memoryUsedMB,
    required this.memoryTotalMB,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'cpuUsage': cpuUsage,
      'memoryUsage': memoryUsage,
      'memoryUsedMB': memoryUsedMB,
      'memoryTotalMB': memoryTotalMB,
    };
  }

  factory PerformanceData.fromJson(Map<String, dynamic> json) {
    return PerformanceData(
      timestamp: DateTime.parse(json['timestamp']),
      cpuUsage: json['cpuUsage'].toDouble(),
      memoryUsage: json['memoryUsage'].toDouble(),
      memoryUsedMB: json['memoryUsedMB'].toDouble(),
      memoryTotalMB: json['memoryTotalMB'].toDouble(),
    );
  }

  List<String> toCsvRow() {
    return [
      timestamp.toIso8601String(),
      cpuUsage.toStringAsFixed(2),
      memoryUsage.toStringAsFixed(2),
      memoryUsedMB.toStringAsFixed(2),
      memoryTotalMB.toStringAsFixed(2),
    ];
  }

  static List<String> get csvHeaders => [
    'Timestamp',
    'CPU Usage (%)',
    'Memory Usage (%)',
    'Memory Used (MB)',
    'Memory Total (MB)',
  ];
}
