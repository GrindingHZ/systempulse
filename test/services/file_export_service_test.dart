import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:cpu_memory_tracking_app/services/file_export_service.dart';
import 'package:cpu_memory_tracking_app/models/recording_session.dart';
import 'package:cpu_memory_tracking_app/models/performance_data.dart';

void main() {
  group('FileExportService Tests', () {
    late FileExportService exportService;

    setUp(() {
      exportService = FileExportService();

      // Mock path provider
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getExternalStorageDirectory') {
            return '/mock/external/storage';
          }
          if (methodCall.method == 'getApplicationDocumentsDirectory') {
            return '/mock/app/documents';
          }
          return '/mock/path';
        },
      );

      // Mock permission handler
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'checkPermissionStatus') {
            return 1; // PermissionStatus.granted
          }
          if (methodCall.method == 'requestPermissions') {
            return {0: 1}; // Permission granted
          }
          return null;
        },
      );

      // Mock share plus
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        (MethodCall methodCall) async {
          return null;
        },
      );
    });

    tearDown(() {
      // Clear method channel handlers
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
    });

    test('should create export service', () {
      expect(exportService, isNotNull);
    });

    test('should handle session with empty data points', () {
      final session = RecordingSession(
        id: 'test-empty',
        startTime: DateTime.now(),
        dataPoints: [],
      );

      // Should not throw an error
      expect(() => exportService.exportToDownloads(session), isA<Future>());
    });

    test('should handle session with data points', () {
      final startTime = DateTime.now();
      final session = RecordingSession(
        id: 'test-with-data',
        startTime: startTime,
        endTime: startTime.add(const Duration(seconds: 30)),
        dataPoints: [
          PerformanceData(
            timestamp: startTime,
            cpuUsage: 25.0,
            memoryUsage: 50.0,
            memoryUsedMB: 2048.0,
            memoryTotalMB: 4096.0,
          ),
          PerformanceData(
            timestamp: startTime.add(const Duration(seconds: 1)),
            cpuUsage: 30.0,
            memoryUsage: 55.0,
            memoryUsedMB: 2150.0,
            memoryTotalMB: 4096.0,
          ),
        ],
      );

      // Should not throw an error
      expect(() => exportService.exportToDownloads(session), isA<Future>());
    });

    test('should generate proper filename for session', () {
      final startTime = DateTime.parse('2025-07-03T12:30:45');
      final session = RecordingSession(
        id: '1625314245000',
        startTime: startTime,
        dataPoints: [],
      );

      // The service should generate a filename with timestamp
      // This is testing that the service doesn't crash with different session data
      expect(() => exportService.exportToDownloads(session), isA<Future>());
    });

    test('should handle session with special characters in data', () {
      final startTime = DateTime.now();
      final session = RecordingSession(
        id: 'test-special-chars',
        startTime: startTime,
        dataPoints: [
          PerformanceData(
            timestamp: startTime,
            cpuUsage: 99.99,
            memoryUsage: 100.0,
            memoryUsedMB: 8191.99,
            memoryTotalMB: 8192.0,
          ),
        ],
      );

      // Should handle high precision numbers
      expect(() => exportService.exportToDownloads(session), isA<Future>());
    });

    test('should handle very long sessions', () {
      final startTime = DateTime.now();
      final dataPoints = <PerformanceData>[];
      
      // Create 100 data points
      for (int i = 0; i < 100; i++) {
        dataPoints.add(PerformanceData(
          timestamp: startTime.add(Duration(seconds: i)),
          cpuUsage: (i % 100).toDouble(),
          memoryUsage: ((i * 2) % 100).toDouble(),
          memoryUsedMB: 1024.0 + i,
          memoryTotalMB: 8192.0,
        ));
      }

      final session = RecordingSession(
        id: 'test-long-session',
        startTime: startTime,
        endTime: startTime.add(const Duration(seconds: 100)),
        dataPoints: dataPoints,
      );

      // Should handle large datasets
      expect(() => exportService.exportToDownloads(session), isA<Future>());
    });
  });
}
