import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:systempulse/data/models/metric_sample.dart';
import 'package:systempulse/data/models/recording_session.dart';
import 'package:systempulse/data/sources/recording_store.dart';

void main() {
  late Directory directory;
  late RecordingStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('systempulse_test');
    store = RecordingStore(directory);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  RecordingSession sessionAt(DateTime start, {String? id}) => RecordingSession(
    id: id ?? 'rec_${start.millisecondsSinceEpoch}',
    startedAt: start,
    intervalSeconds: 1,
  );

  test('saves and lists a session', () async {
    final session = sessionAt(DateTime.utc(2026, 3, 1, 10));
    await store.saveSession(session);

    final listed = await store.listSessions();
    expect(listed, hasLength(1));
    expect(listed.first.id, session.id);
    expect(listed.first.intervalSeconds, 1);
  });

  test('lists newest first', () async {
    await store.saveSession(sessionAt(DateTime.utc(2026, 3, 1, 10), id: 'older'));
    await store.saveSession(sessionAt(DateTime.utc(2026, 3, 2, 10), id: 'newer'));

    final listed = await store.listSessions();
    expect(listed.map((s) => s.id), ['newer', 'older']);
  });

  test('appends and reads back samples in order', () async {
    final session = sessionAt(DateTime.utc(2026, 3, 1, 10));
    await store.saveSession(session);

    for (var i = 0; i < 3; i++) {
      await store.appendSample(
        session.id,
        MetricSample(timestamp: DateTime.utc(2026, 3, 1, 10, 0, i), cpuPercent: i.toDouble()),
      );
    }

    final samples = await store.loadSamples(session.id);
    expect(samples.map((s) => s.cpuPercent), [0.0, 1.0, 2.0]);
    expect(await store.countSamples(session.id), 3);
  });

  test('a truncated final line does not discard the samples before it', () async {
    // Exactly what a process kill mid-write leaves behind. Losing an entire session over its last
    // partial line would defeat the point of writing incrementally.
    final session = sessionAt(DateTime.utc(2026, 3, 1, 10));
    await store.saveSession(session);

    final good = jsonEncode(
      MetricSample(timestamp: DateTime.utc(2026, 3, 1, 10), cpuPercent: 5).toJson(),
    );
    await store.samplesFile(session.id).writeAsString('$good\n$good\n{"t":170000,"cpuPer');

    final samples = await store.loadSamples(session.id);
    expect(samples, hasLength(2));
    expect(samples.every((s) => s.cpuPercent == 5), isTrue);
  });

  test('an unreadable header is skipped instead of hiding every other session', () async {
    await store.saveSession(sessionAt(DateTime.utc(2026, 3, 1, 10), id: 'good'));
    await File('${directory.path}/corrupt.json').writeAsString('{not json');

    final listed = await store.listSessions();
    expect(listed.map((s) => s.id), ['good']);
  });

  test('deleting removes both the header and the samples', () async {
    final session = sessionAt(DateTime.utc(2026, 3, 1, 10));
    await store.saveSession(session);
    await store.appendSample(session.id, MetricSample(timestamp: DateTime.utc(2026, 3, 1, 10)));

    await store.deleteSession(session.id);

    expect(await store.listSessions(), isEmpty);
    expect(await store.samplesFile(session.id).exists(), isFalse);
  });

  group('recoverInterruptedSessions', () {
    test('closes an active session at its last recorded sample', () async {
      final session = sessionAt(DateTime.utc(2026, 3, 1, 10));
      await store.saveSession(session);

      final lastSampleAt = DateTime.utc(2026, 3, 1, 10, 4, 30);
      await store.appendSample(
        session.id,
        MetricSample(timestamp: DateTime.utc(2026, 3, 1, 10, 0, 1), cpuPercent: 1),
      );
      await store.appendSample(session.id, MetricSample(timestamp: lastSampleAt, cpuPercent: 2));

      final recovered = await store.recoverInterruptedSessions();

      expect(recovered, hasLength(1));
      expect(recovered.first.isActive, isFalse);
      expect(recovered.first.recoveredAfterCrash, isTrue);
      expect(recovered.first.sampleCount, 2);
      // The end time is the last real sample, not the moment recovery happened, so the duration
      // reflects what was actually measured.
      expect(recovered.first.endedAt, lastSampleAt);
    });

    test('a session with no samples ends at its start time', () async {
      final start = DateTime.utc(2026, 3, 1, 10);
      await store.saveSession(sessionAt(start));

      final recovered = await store.recoverInterruptedSessions();

      expect(recovered.first.endedAt, start);
      expect(recovered.first.duration, Duration.zero);
    });

    test('leaves already-finished sessions alone', () async {
      await store.saveSession(
        RecordingSession(
          id: 'done',
          startedAt: DateTime.utc(2026, 3, 1, 10),
          endedAt: DateTime.utc(2026, 3, 1, 11),
          sampleCount: 5,
        ),
      );

      expect(await store.recoverInterruptedSessions(), isEmpty);
      final listed = await store.listSessions();
      expect(listed.first.recoveredAfterCrash, isFalse);
      expect(listed.first.sampleCount, 5);
    });
  });
}
