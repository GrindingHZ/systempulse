class PerformanceData {
  final double cpuUsage;
  final double memoryUsage;
  final DateTime timestamp;

  PerformanceData({
    required this.cpuUsage,
    required this.memoryUsage,
    required this.timestamp,
  });

  factory PerformanceData.fromMap(Map<String, dynamic> map) {
    return PerformanceData(
      cpuUsage: (map['cpuUsage'] ?? 0.0).toDouble(),
      memoryUsage: (map['memoryUsage'] ?? 0.0).toDouble(),
      timestamp: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'PerformanceData(cpuUsage: $cpuUsage%, memoryUsage: $memoryUsage%)';
  }
}
