import 'package:flutter_test/flutter_test.dart';
import 'package:systempulse/data/models/metric_sample.dart';
import 'package:systempulse/data/models/recording_session.dart';
import 'package:systempulse/data/sources/csv_exporter.dart';

void main() {
  group('MetricSummary', () {
    test('averages only the readings that exist', () {
      // The defect this guards against: treating a missing reading as 0 pulls the average down.
      // Here the mean of 10 and 20 must be 15, not 10.
      final summary = MetricSummary.from([10.0, null, 20.0, null]);

      expect(summary.count, 2);
      expect(summary.average, 15.0);
      expect(summary.minimum, 10.0);
      expect(summary.maximum, 20.0);
    });

    test('reports no data rather than zeros when every reading is missing', () {
      final summary = MetricSummary.from([null, null]);

      expect(summary.hasData, isFalse);
      expect(summary.count, 0);
    });

    test('a genuine zero is included in the statistics', () {
      final summary = MetricSummary.from([0.0, 10.0]);

      expect(summary.count, 2);
      expect(summary.minimum, 0.0);
      expect(summary.average, 5.0);
    });

    test('handles a single reading', () {
      final summary = MetricSummary.from([42.0]);

      expect(summary.minimum, 42.0);
      expect(summary.maximum, 42.0);
      expect(summary.average, 42.0);
    });
  });

  group('SessionDetail', () {
    test('summarises each metric independently', () {
      final detail = SessionDetail(
        session: RecordingSession(id: 'r', startedAt: DateTime.utc(2026)),
        samples: [
          MetricSample(
            timestamp: DateTime.utc(2026, 1, 1, 0, 0, 0),
            cpuPercent: 10,
            batteryPercent: 80,
          ),
          MetricSample(
            timestamp: DateTime.utc(2026, 1, 1, 0, 0, 1),
            cpuPercent: 30,
            // Battery missing for this sample only.
          ),
        ],
      );

      expect(detail.cpu.count, 2);
      expect(detail.cpu.average, 20.0);
      expect(detail.battery.count, 1);
      expect(detail.battery.average, 80.0);
      expect(detail.deviceMemory.hasData, isFalse);
      expect(detail.sawLowMemory, isFalse);
    });

    test('flags a session where the device reported memory pressure', () {
      final detail = SessionDetail(
        session: RecordingSession(id: 'r', startedAt: DateTime.utc(2026)),
        samples: [
          MetricSample(timestamp: DateTime.utc(2026), deviceLowMemory: false),
          MetricSample(timestamp: DateTime.utc(2026), deviceLowMemory: true),
        ],
      );

      expect(detail.sawLowMemory, isTrue);
    });
  });

  group('timestamps', () {
    test('exported timestamps carry a zone designator', () {
      // An ISO-8601 string with no zone is ambiguous to whoever opens the CSV, and a recording
      // spanning a DST change would contain timestamps that appear to move backwards.
      final csv = CsvExporter.build(
        RecordingSession(
          id: 'r',
          startedAt: DateTime.utc(2026, 3, 1, 10),
          endedAt: DateTime.utc(2026, 3, 1, 11),
        ),
        [
          MetricSample.fromMap({'t': 1772359200000, 'cpuPercent': 5, 'cpuAvailable': true}),
        ],
      );

      final dataRow = csv.trim().split('\n').where((line) => !line.startsWith('#')).skip(1).first;

      expect(dataRow.split(',').first, endsWith('Z'));
      expect(csv, contains('# started_at,2026-03-01T10:00:00.000Z'));
    });

    test('duration is unaffected by the local timezone', () {
      final session = RecordingSession(
        id: 'r',
        startedAt: DateTime.utc(2026, 3, 1, 10),
        endedAt: DateTime.utc(2026, 3, 1, 12, 30),
      );

      expect(session.duration, const Duration(hours: 2, minutes: 30));
    });
  });
}
