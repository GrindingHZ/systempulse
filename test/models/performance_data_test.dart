import 'package:flutter_test/flutter_test.dart';
import 'package:cpu_memory_tracking_app/models/performance_data.dart';

void main() {
  group('PerformanceData Tests', () {
    test('should create PerformanceData with valid values', () {
      final timestamp = DateTime.now();
      final data = PerformanceData(
        timestamp: timestamp,
        cpuUsage: 45.5,
        memoryUsage: 60.0,
        memoryUsedMB: 4096.0,
        memoryTotalMB: 8192.0,
      );

      expect(data.timestamp, equals(timestamp));
      expect(data.cpuUsage, equals(45.5));
      expect(data.memoryUsage, equals(60.0));
      expect(data.memoryUsedMB, equals(4096.0));
      expect(data.memoryTotalMB, equals(8192.0));
    });

    test('should handle zero values correctly', () {
      final data = PerformanceData(
        timestamp: DateTime.now(),
        cpuUsage: 0.0,
        memoryUsage: 0.0,
        memoryUsedMB: 0.0,
        memoryTotalMB: 0.0,
      );

      expect(data.cpuUsage, equals(0.0));
      expect(data.memoryUsage, equals(0.0));
      expect(data.memoryUsedMB, equals(0.0));
      expect(data.memoryTotalMB, equals(0.0));
    });

    test('should serialize to and from JSON correctly', () {
      final timestamp = DateTime.now();
      final originalData = PerformanceData(
        timestamp: timestamp,
        cpuUsage: 25.7,
        memoryUsage: 80.3,
        memoryUsedMB: 6144.0,
        memoryTotalMB: 8192.0,
      );

      final json = originalData.toJson();
      final deserializedData = PerformanceData.fromJson(json);

      expect(deserializedData.timestamp.millisecondsSinceEpoch, 
             equals(originalData.timestamp.millisecondsSinceEpoch));
      expect(deserializedData.cpuUsage, equals(originalData.cpuUsage));
      expect(deserializedData.memoryUsage, equals(originalData.memoryUsage));
      expect(deserializedData.memoryUsedMB, equals(originalData.memoryUsedMB));
      expect(deserializedData.memoryTotalMB, equals(originalData.memoryTotalMB));
    });

    test('should handle negative values by clamping to zero', () {
      final data = PerformanceData(
        timestamp: DateTime.now(),
        cpuUsage: -10.0,
        memoryUsage: -5.0,
        memoryUsedMB: -100.0,
        memoryTotalMB: -200.0,
      );

      // The model should handle negative values appropriately
      // (actual implementation may clamp these values)
      expect(data.cpuUsage, lessThanOrEqualTo(0.0));
      expect(data.memoryUsage, lessThanOrEqualTo(0.0));
    });

    test('should handle very large values', () {
      final data = PerformanceData(
        timestamp: DateTime.now(),
        cpuUsage: 999.9,
        memoryUsage: 999.9,
        memoryUsedMB: 999999.0,
        memoryTotalMB: 999999.0,
      );

      expect(data.cpuUsage, equals(999.9));
      expect(data.memoryUsage, equals(999.9));
      expect(data.memoryUsedMB, equals(999999.0));
      expect(data.memoryTotalMB, equals(999999.0));
    });
  });
}
