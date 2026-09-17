import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:systempulse/data/models/metric_sample.dart';

void main() {
  group('MetricSample.fromMap', () {
    test('reads a complete platform payload', () {
      final sample = MetricSample.fromMap({
        't': 1700000000000,
        'cpuPercent': 12.5,
        'cpuPerCorePercent': 100.0,
        'cpuAvailable': true,
        'deviceMemoryPercent': 71.25,
        'deviceMemoryUsedBytes': 6000000000,
        'deviceMemoryTotalBytes': 8000000000,
        'appMemoryBytes': 152000000,
        'deviceLowMemory': false,
        'memoryAvailable': true,
        'batteryPercent': 82.0,
        'batteryTemperatureC': 31.4,
        'batteryStatus': 'Discharging',
        'batteryCharging': false,
        'batteryAvailable': true,
      });

      expect(sample.timestamp.millisecondsSinceEpoch, 1700000000000);
      expect(sample.cpuPercent, 12.5);
      expect(sample.cpuPerCorePercent, 100.0);
      expect(sample.deviceMemoryPercent, 71.25);
      expect(sample.batteryStatus, 'Discharging');
      expect(sample.hasAnyReading, isTrue);
    });

    test('an unavailable metric becomes null, never zero', () {
      // The distinction this asserts is the whole point of the availability flags: a zero would be
      // indistinguishable from a genuine idle reading once it reaches a chart or a CSV.
      final sample = MetricSample.fromMap({
        't': 1700000000000,
        'cpuPercent': 0.0,
        'cpuAvailable': false,
        'deviceMemoryPercent': 0.0,
        'memoryAvailable': false,
        'batteryPercent': 0.0,
        'batteryAvailable': false,
      });

      expect(sample.cpuPercent, isNull);
      expect(sample.deviceMemoryPercent, isNull);
      expect(sample.batteryPercent, isNull);
      expect(sample.batteryStatus, isNull);
      expect(sample.hasAnyReading, isFalse);
    });

    test('a genuine zero reading is preserved when the metric is available', () {
      final sample = MetricSample.fromMap({
        't': 1700000000000,
        'cpuPercent': 0.0,
        'cpuAvailable': true,
      });

      expect(sample.cpuPercent, 0.0);
      expect(sample.hasAnyReading, isTrue);
    });

    test('integer-typed doubles from the platform channel are accepted', () {
      // Android returns whole numbers as Integer, which arrive as int rather than double.
      final sample = MetricSample.fromMap({
        't': 1700000000000,
        'cpuPercent': 12,
        'cpuAvailable': true,
      });

      expect(sample.cpuPercent, 12.0);
    });
  });

  group('MetricSample.tryDecodeLine', () {
    test('round-trips through JSON preserving nulls', () {
      final original = MetricSample(
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        cpuPercent: 9.5,
        deviceMemoryPercent: null,
        batteryPercent: 44.0,
      );

      final decoded = MetricSample.tryDecodeLine(jsonEncode(original.toJson()));

      expect(decoded, isNotNull);
      expect(decoded!.cpuPercent, 9.5);
      expect(decoded.deviceMemoryPercent, isNull);
      expect(decoded.batteryPercent, 44.0);
    });

    test('returns null for a truncated final line rather than throwing', () {
      // Expected after a process kill mid-write. The reader must skip it and keep every complete
      // line before it.
      expect(MetricSample.tryDecodeLine('{"t":1700000000000,"cpuPer'), isNull);
      expect(MetricSample.tryDecodeLine(''), isNull);
      expect(MetricSample.tryDecodeLine('   '), isNull);
      expect(MetricSample.tryDecodeLine('[1,2,3]'), isNull);
    });
  });
}
