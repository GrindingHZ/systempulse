import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:cpu_memory_tracking_app/providers/performance_provider.dart';

void main() {
  group('PerformanceProvider Tests', () {
    late PerformanceProvider provider;

    setUp(() {
      // Reset method channel bindings before each test
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('performance_tracker'),
        null,
      );
      
      // Mock shared preferences
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter.io/shared_preferences'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getAll') {
            return <String, dynamic>{};
          }
          return null;
        },
      );

      // Mock device info plus
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/device_info'),
        (MethodCall methodCall) async {
          return <String, dynamic>{};
        },
      );

      // Mock path provider
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async {
          return '/test/path';
        },
      );

      // Mock notifications
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (MethodCall methodCall) async {
          return null;
        },
      );

      provider = PerformanceProvider();
    });

    tearDown(() {
      provider.dispose();
      // Clear all method channel handlers
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('performance_tracker'),
        null,
      );
    });

    test('should initialize with default values', () {
      expect(provider.isRecording, isFalse);
      expect(provider.currentSession, isNull);
      expect(provider.sessions, isEmpty);
      expect(provider.recordingInterval, equals(1));
      expect(provider.chartDurationSeconds, equals(60));
      expect(provider.liveChartData, isEmpty);
    });

    test('should update recording interval', () async {
      await provider.setSamplingInterval(5);
      expect(provider.recordingInterval, equals(5));
      expect(provider.getSamplingIntervalText(), equals('5 seconds'));
    });

    test('should handle boundary values for recording interval', () async {
      // Test minimum value
      await provider.setSamplingInterval(-1);
      expect(provider.recordingInterval, equals(1)); // Should clamp to 1

      // Test maximum value
      await provider.setSamplingInterval(120);
      expect(provider.recordingInterval, equals(60)); // Should clamp to 60

      // Test normal value
      await provider.setSamplingInterval(10);
      expect(provider.recordingInterval, equals(10));
    });

    test('should format sampling interval text correctly', () async {
      await provider.setSamplingInterval(1);
      expect(provider.getSamplingIntervalText(), equals('1 second'));

      await provider.setSamplingInterval(10);
      expect(provider.getSamplingIntervalText(), equals('10 seconds'));

      await provider.setSamplingInterval(60);
      expect(provider.getSamplingIntervalText(), equals('1 minute'));
    });

    test('should update chart duration and clean up data', () {
      provider.setChartDuration(120);
      expect(provider.chartDurationSeconds, equals(120));

      // Test boundary values
      provider.setChartDuration(10); // Below minimum
      expect(provider.chartDurationSeconds, equals(30)); // Should clamp to 30

      provider.setChartDuration(600); // Above maximum
      expect(provider.chartDurationSeconds, equals(300)); // Should clamp to 300
    });

    test('should handle mock performance data collection', () async {
      // Mock the performance tracker channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('performance_tracker'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getCurrentPerformance') {
            return {
              'cpuUsage': 45.5,
              'memoryUsage': 60.0,
              'memoryUsedMB': 4096.0,
              'memoryTotalMB': 8192.0,
            };
          }
          return null;
        },
      );

      // Wait a moment for the live monitoring to collect data
      await Future.delayed(const Duration(milliseconds: 1100));

      expect(provider.currentData, isNotNull);
      if (provider.currentData != null) {
        expect(provider.currentData!.cpuUsage, equals(45.5));
        expect(provider.currentData!.memoryUsage, equals(60.0));
      }
    });

    test('should handle recording lifecycle', () async {
      expect(provider.isRecording, isFalse);
      expect(provider.currentSession, isNull);

      await provider.startRecording();
      
      expect(provider.isRecording, isTrue);
      expect(provider.currentSession, isNotNull);
      expect(provider.currentSession!.dataPoints, isNotEmpty);

      await provider.stopRecording();
      
      expect(provider.isRecording, isFalse);
      expect(provider.currentSession, isNull);
      expect(provider.sessions.length, equals(1));
    });

    test('should prevent multiple simultaneous recordings', () async {
      await provider.startRecording();
      final firstSessionId = provider.currentSession?.id;
      
      await provider.startRecording(); // Should be ignored
      
      expect(provider.currentSession?.id, equals(firstSessionId));
      
      await provider.stopRecording();
    });

    test('should handle graceful error when stopping recording without starting', () async {
      expect(provider.isRecording, isFalse);
      
      // This should not throw an error
      await provider.stopRecording();
      
      expect(provider.isRecording, isFalse);
      expect(provider.sessions, isEmpty);
    });

    test('should calculate current recording duration', () async {
      expect(provider.currentRecordingDuration, equals(Duration.zero));
      
      await provider.startRecording();
      
      // Wait a moment
      await Future.delayed(const Duration(milliseconds: 100));
      
      expect(provider.currentRecordingDuration.inMilliseconds, greaterThan(0));
      
      await provider.stopRecording();
      
      expect(provider.currentRecordingDuration, equals(Duration.zero));
    });

    test('should handle session deletion', () async {
      // Create a recording session
      await provider.startRecording();
      await Future.delayed(const Duration(milliseconds: 100));
      await provider.stopRecording();
      
      expect(provider.sessions.length, equals(1));
      final sessionId = provider.sessions.first.id;
      
      await provider.deleteSession(sessionId);
      
      expect(provider.sessions, isEmpty);
    });

    test('should handle deletion of non-existent session', () async {
      // Try to delete a session that doesn't exist
      await provider.deleteSession('non-existent-id');
      
      // Should not throw an error and sessions should remain empty
      expect(provider.sessions, isEmpty);
    });

    test('should handle platform channel errors gracefully', () async {
      // Mock a failing platform channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('performance_tracker'),
        (MethodCall methodCall) async {
          throw PlatformException(code: 'ERROR', message: 'Test error');
        },
      );

      // Should not throw an error, should use fallback values
      await Future.delayed(const Duration(milliseconds: 1100));
      
      expect(provider.currentData, isNotNull);
      if (provider.currentData != null) {
        expect(provider.currentData!.cpuUsage, equals(0.0));
        expect(provider.currentData!.memoryUsage, equals(0.0));
      }
    });

    test('should handle null response from platform channel', () async {
      // Mock a null response from platform channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('performance_tracker'),
        (MethodCall methodCall) async {
          return null;
        },
      );

      await Future.delayed(const Duration(milliseconds: 1100));
      
      expect(provider.currentData, isNotNull);
      if (provider.currentData != null) {
        expect(provider.currentData!.cpuUsage, equals(0.0));
        expect(provider.currentData!.memoryUsage, equals(0.0));
      }
    });
  });
}
