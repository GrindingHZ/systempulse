import 'package:flutter_test/flutter_test.dart';
import 'package:systempulse/data/models/metric_sample.dart';
import 'package:systempulse/data/models/recording_session.dart';
import 'package:systempulse/data/sources/csv_exporter.dart';

void main() {
  final session = RecordingSession(
    id: 'rec_1',
    startedAt: DateTime.utc(2026, 3, 1, 10),
    endedAt: DateTime.utc(2026, 3, 1, 10, 5),
    sampleCount: 2,
    intervalSeconds: 1,
  );

  /// The data rows, with metadata comments and the header stripped.
  List<String> dataRows(String csv) =>
      csv.trim().split('\n').where((line) => !line.startsWith('#')).skip(1).toList();

  test('writes one row per sample with a stable column count', () {
    final csv = CsvExporter.build(session, [
      MetricSample(
        timestamp: DateTime.utc(2026, 3, 1, 10, 0, 1),
        cpuPercent: 12.345,
        cpuPerCorePercent: 98.7,
        deviceMemoryPercent: 71.2,
        deviceMemoryUsedBytes: 6000000000,
        deviceMemoryTotalBytes: 8000000000,
        appMemoryBytes: 152000000,
        batteryPercent: 82.0,
        batteryTemperatureC: 31.44,
        batteryStatus: 'Discharging',
        batteryCharging: false,
      ),
    ]);

    final rows = dataRows(csv);
    expect(rows, hasLength(1));
    expect(rows.first.split(',').first, '2026-03-01T10:00:01.000Z');
    expect(rows.first.split(','), hasLength(12));
    expect(rows.first, contains('12.35')); // rounded to 2dp
  });

  test('a missing reading becomes an empty field, not zero', () {
    // Writing 0.00 for a failed read silently drags every average in a spreadsheet downward,
    // because a zero is counted as a measurement while a blank cell is not.
    final csv = CsvExporter.build(session, [
      MetricSample(timestamp: DateTime.utc(2026, 3, 1, 10, 0, 1)),
    ]);

    final fields = dataRows(csv).first.split(',');
    expect(fields[0], isNotEmpty); // timestamp always present
    expect(fields[1], isEmpty); // cpu
    expect(fields[3], isEmpty); // device memory
    expect(fields[8], isEmpty); // battery
    expect(fields[9], isEmpty); // temperature
    expect(fields[11], isEmpty); // charging
  });

  test('a field containing a comma is quoted so columns do not shift', () {
    // batteryStatus is a platform-supplied string, so this is a real risk rather than theoretical.
    final csv = CsvExporter.build(session, [
      MetricSample(
        timestamp: DateTime.utc(2026, 3, 1, 10, 0, 1),
        batteryPercent: 50,
        batteryStatus: 'Charging, slowly',
      ),
    ]);

    final row = dataRows(csv).first;
    expect(row, contains('"Charging, slowly"'));
    // The quoted comma must not create a thirteenth column.
    expect(_splitCsv(row), hasLength(12));
  });

  test('an embedded quote is doubled per RFC 4180', () {
    final csv = CsvExporter.build(session, [
      MetricSample(
        timestamp: DateTime.utc(2026, 3, 1, 10, 0, 1),
        batteryPercent: 50,
        batteryStatus: 'He said "full"',
      ),
    ]);

    expect(dataRows(csv).first, contains('"He said ""full"""'));
  });

  test('metadata states what the CPU column means', () {
    // The same column name meant a completely different quantity in exports from earlier versions
    // of this app, so the definition travels with the data.
    final csv = CsvExporter.build(session, const []);
    expect(csv, contains('# cpu_percent_of_device:'));
    expect(csv, contains('core count'));
    expect(csv, contains('# sample_count,0'));
  });

  test('file name is free of characters that are illegal in a path', () {
    final name = CsvExporter.fileNameFor(session);
    expect(name, endsWith('.csv'));
    expect(name, isNot(contains(':')));
  });
}

/// Minimal RFC 4180 field splitter, used to prove quoting actually protects the column count.
List<String> _splitCsv(String line) {
  final fields = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char == ',' && !inQuotes) {
      fields.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  fields.add(buffer.toString());
  return fields;
}
