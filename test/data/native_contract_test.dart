import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:systempulse/data/models/recording_session.dart';
import 'package:systempulse/data/sources/csv_exporter.dart';
import 'package:systempulse/data/sources/recording_store.dart';

/// Verifies the contract between the native recorder and the Dart reader.
///
/// `test/fixtures/native_samples.jsonl` was produced by running the production Kotlin
/// `SampleWriter` — it is real output, not a hand-written approximation of it. The two sides speak
/// through this file format and nothing else, so a change to either that breaks the other should
/// fail here rather than on a user's device.
///
/// Regenerate it from `android/app/src/test/kotlin/.../SampleWriterTest.kt`'s sample shape if the
/// schema ever changes.
void main() {
  late Directory directory;
  late RecordingStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('systempulse_contract');
    store = RecordingStore(directory);
    // Place the native output where the store expects a session's samples to live.
    await File('test/fixtures/native_samples.jsonl').copy(store.samplesFile('native').path);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('reads samples written by the native recorder', () async {
    final samples = await store.loadSamples('native');

    // Two complete records; the third line is a deliberate mid-write truncation.
    expect(samples, hasLength(2));
    expect(
      samples.first.timestamp,
      DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
    );
    expect(samples.first.cpuPercent, 12.5);
    expect(samples.first.deviceMemoryTotalBytes, 12884901888);
  });

  test('whole-number doubles from org.json decode correctly', () async {
    // The JVM's JSON encoder writes 77.0 as `77`, so it arrives as an int. Reading it as a double
    // directly would throw and lose the sample.
    final samples = await store.loadSamples('native');

    expect(samples.first.batteryPercent, 77.0);
    expect(samples.first.cpuPerCorePercent, 100.0);
  });

  test('a metric the device could not read arrives as null, not zero', () async {
    final samples = await store.loadSamples('native');
    final second = samples[1];

    // The native side writes cpuPercent 0.0 alongside cpuAvailable false. Honouring only the
    // number would record a phantom idle reading.
    expect(second.cpuPercent, isNull);
    expect(second.cpuPerCorePercent, isNull);

    // Metrics that were readable in the same sample are unaffected.
    expect(second.deviceMemoryPercent, 62.0);
    expect(second.batteryPercent, 76.0);
    expect(second.deviceLowMemory, isTrue);
  });

  test('a truncated trailing line is skipped without losing earlier samples', () async {
    final raw = await File('test/fixtures/native_samples.jsonl').readAsString();
    expect(raw.trimRight(), endsWith('"cpuPer'), reason: 'fixture must retain its partial line');

    expect((await store.loadSamples('native')), hasLength(2));
  });

  test('a battery status containing a comma survives into valid CSV', () async {
    final samples = await store.loadSamples('native');
    final csv = CsvExporter.build(
      RecordingSession(
        id: 'native',
        startedAt: DateTime.utc(2026, 3, 1, 10),
        endedAt: DateTime.utc(2026, 3, 1, 10, 1),
      ),
      samples,
    );

    final rows = csv.trim().split('\n').where((line) => !line.startsWith('#')).skip(1).toList();

    expect(rows, hasLength(2));
    // The native value is "Charging, slowly"; unquoted it would add a column to this row.
    expect(rows[1], contains('"Charging, slowly"'));
    expect(rows[0].split(',').length, rows[1].split(',').length - 1);

    // The unavailable CPU reading is an empty field, not 0.00.
    expect(rows[1].split(',')[1], isEmpty);
  });
}
