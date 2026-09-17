import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/metric_sample.dart';
import '../models/recording_session.dart';

/// File-backed storage for recordings.
///
/// Replaces storing every session, with every sample, as one JSON string in SharedPreferences.
/// SharedPreferences loads its entire contents into memory at startup and rewrites the whole file
/// on each commit, so that design grew a multi-megabyte blob that was re-encoded on every sample —
/// and one corrupt entry took every session with it.
///
/// The layout on disk is:
///
///   `sessions/<id>.json`    small header: id, timestamps, sample count
///   `sessions/<id>.jsonl`   append-only sample stream, one JSON object per line
///
/// Headers are small and read eagerly for the history list. Sample streams are read only when a
/// session is opened. The native recording service appends to the same `.jsonl` files, so a
/// recording in progress is already durable before Dart hears about it.
class RecordingStore {
  RecordingStore(this._directory);

  final Directory _directory;

  static const String _headerExtension = '.json';
  static const String _samplesExtension = '.jsonl';

  Future<Directory> _ensureDirectory() async {
    if (!await _directory.exists()) {
      await _directory.create(recursive: true);
    }
    return _directory;
  }

  File _headerFile(String id) => File('${_directory.path}/$id$_headerExtension');
  File samplesFile(String id) => File('${_directory.path}/$id$_samplesExtension');

  /// All known sessions, newest first.
  ///
  /// A header that cannot be read or parsed is skipped rather than aborting the listing, so one bad
  /// file cannot hide every other recording.
  Future<List<RecordingSession>> listSessions() async {
    final directory = await _ensureDirectory();
    final sessions = <RecordingSession>[];

    await for (final entity in directory.list()) {
      if (entity is! File || !entity.path.endsWith(_headerExtension)) continue;
      final session = await _readHeader(entity);
      if (session != null) sessions.add(session);
    }

    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }

  Future<RecordingSession?> _readHeader(File file) async {
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      return RecordingSession.tryFromJson(decoded);
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  Future<void> saveSession(RecordingSession session) async {
    await _ensureDirectory();
    // Written to a temporary file and renamed, because rename is atomic on the same filesystem.
    // A direct write interrupted by a process kill would leave a truncated header that no longer
    // parses, losing a session whose samples are intact on disk beside it.
    final target = _headerFile(session.id);
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(jsonEncode(session.toJson()), flush: true);
    await temporary.rename(target.path);
  }

  /// Reads every sample for [id].
  ///
  /// Lines that fail to parse are skipped. This is expected rather than exceptional: a process
  /// killed mid-write leaves a partial final line, and every complete line before it is still good.
  Future<List<MetricSample>> loadSamples(String id) async {
    final file = samplesFile(id);
    if (!await file.exists()) return const [];

    final samples = <MetricSample>[];
    try {
      final lines = file.openRead().transform(utf8.decoder).transform(const LineSplitter());

      await for (final line in lines) {
        final sample = MetricSample.tryDecodeLine(line);
        if (sample != null) samples.add(sample);
      }
    } on FileSystemException {
      return samples;
    }
    return samples;
  }

  /// Counts samples without decoding them, for refreshing a session header cheaply.
  Future<int> countSamples(String id) async {
    final file = samplesFile(id);
    if (!await file.exists()) return 0;

    var count = 0;
    try {
      final lines = file.openRead().transform(utf8.decoder).transform(const LineSplitter());
      await for (final line in lines) {
        if (line.trim().isNotEmpty) count++;
      }
    } on FileSystemException {
      return count;
    }
    return count;
  }

  /// Appends one sample. Used for sampling driven from Dart; the native service writes directly.
  Future<void> appendSample(String id, MetricSample sample) async {
    await _ensureDirectory();
    await samplesFile(
      id,
    ).writeAsString('${jsonEncode(sample.toJson())}\n', mode: FileMode.append, flush: false);
  }

  Future<void> deleteSession(String id) async {
    for (final file in [_headerFile(id), samplesFile(id)]) {
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // A file that cannot be removed should not prevent the other from being cleaned up.
      }
    }
  }

  /// Closes out any session left marked active by a process death.
  ///
  /// Called at launch. The samples are already on disk, so recovery is a matter of stamping the
  /// header with the timestamp of the last sample actually recorded and marking it recovered, so
  /// the history list can say what happened instead of showing a recording that never ends.
  Future<List<RecordingSession>> recoverInterruptedSessions() async {
    final recovered = <RecordingSession>[];

    for (final session in await listSessions()) {
      if (!session.isActive) continue;

      final samples = await loadSamples(session.id);
      final endedAt = samples.isNotEmpty ? samples.last.timestamp : session.startedAt;
      final closed = session.copyWith(
        endedAt: endedAt,
        sampleCount: samples.length,
        recoveredAfterCrash: true,
      );
      await saveSession(closed);
      recovered.add(closed);
    }

    return recovered;
  }
}
