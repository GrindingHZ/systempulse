import 'package:flutter_test/flutter_test.dart';
import 'package:cpu_memory_tracking_app/models/recording_session.dart';
import 'package:cpu_memory_tracking_app/models/performance_data.dart';

void main() {
  group('RecordingSession Tests', () {
    late DateTime startTime;
    late DateTime endTime;
    late List<PerformanceData> sampleDataPoints;

    setUp(() {
      startTime = DateTime.now();
      endTime = startTime.add(const Duration(seconds: 30));
      sampleDataPoints = [
        PerformanceData(
          timestamp: startTime,
          cpuUsage: 10.0,
          memoryUsage: 20.0,
          memoryUsedMB: 1024.0,
          memoryTotalMB: 8192.0,
        ),
        PerformanceData(
          timestamp: startTime.add(const Duration(seconds: 1)),
          cpuUsage: 15.0,
          memoryUsage: 25.0,
          memoryUsedMB: 1100.0,
          memoryTotalMB: 8192.0,
        ),
      ];
    });

    test('should create RecordingSession with required fields', () {
      final session = RecordingSession(
        id: 'test-session-1',
        startTime: startTime,
        dataPoints: sampleDataPoints,
      );

      expect(session.id, equals('test-session-1'));
      expect(session.startTime, equals(startTime));
      expect(session.endTime, isNull);
      expect(session.dataPoints.length, equals(2));
      expect(session.filePath, isNull);
    });

    test('should calculate duration correctly when session is ongoing', () {
      final session = RecordingSession(
        id: 'test-session-2',
        startTime: startTime,
        dataPoints: sampleDataPoints,
      );

      final duration = session.duration;
      expect(duration.inSeconds, greaterThanOrEqualTo(0));
    });

    test('should calculate duration correctly when session is ended', () {
      final session = RecordingSession(
        id: 'test-session-3',
        startTime: startTime,
        endTime: endTime,
        dataPoints: sampleDataPoints,
      );

      expect(session.duration.inSeconds, equals(30));
    });

    test('should copy session with new values', () {
      final originalSession = RecordingSession(
        id: 'original-session',
        startTime: startTime,
        dataPoints: [sampleDataPoints.first],
      );

      final copiedSession = originalSession.copyWith(
        endTime: endTime,
        dataPoints: sampleDataPoints,
        filePath: '/path/to/file.csv',
      );

      expect(copiedSession.id, equals(originalSession.id));
      expect(copiedSession.startTime, equals(originalSession.startTime));
      expect(copiedSession.endTime, equals(endTime));
      expect(copiedSession.dataPoints.length, equals(2));
      expect(copiedSession.filePath, equals('/path/to/file.csv'));
    });

    test('should serialize to and from JSON correctly', () {
      final originalSession = RecordingSession(
        id: 'json-test-session',
        startTime: startTime,
        endTime: endTime,
        dataPoints: sampleDataPoints,
        filePath: '/test/path.csv',
      );

      final json = originalSession.toJson();
      final deserializedSession = RecordingSession.fromJson(json);

      expect(deserializedSession.id, equals(originalSession.id));
      expect(deserializedSession.startTime.millisecondsSinceEpoch,
             equals(originalSession.startTime.millisecondsSinceEpoch));
      expect(deserializedSession.endTime?.millisecondsSinceEpoch,
             equals(originalSession.endTime?.millisecondsSinceEpoch));
      expect(deserializedSession.dataPoints.length, equals(originalSession.dataPoints.length));
      expect(deserializedSession.filePath, equals(originalSession.filePath));
    });

    test('should handle empty data points list', () {
      final session = RecordingSession(
        id: 'empty-session',
        startTime: startTime,
        dataPoints: [],
      );

      expect(session.dataPoints.length, equals(0));
      expect(session.duration.inSeconds, greaterThanOrEqualTo(0));
    });

    test('should handle session without file path', () {
      final session = RecordingSession(
        id: 'no-file-session',
        startTime: startTime,
        endTime: endTime,
        dataPoints: sampleDataPoints,
      );

      final json = session.toJson();
      final deserializedSession = RecordingSession.fromJson(json);

      expect(deserializedSession.filePath, isNull);
    });

    test('should preserve data point order', () {
      final session = RecordingSession(
        id: 'ordered-session',
        startTime: startTime,
        dataPoints: sampleDataPoints,
      );

      expect(session.dataPoints.first.cpuUsage, equals(10.0));
      expect(session.dataPoints.last.cpuUsage, equals(15.0));
    });
  });
}
