import 'metric_sample.dart';

/// Summary statistics for one metric across a session.
///
/// Computed in a single pass and skipping unavailable readings, so a run where the platform
/// reported nothing yields [count] == 0 rather than an average of zeros.
class MetricSummary {
  const MetricSummary({
    required this.count,
    required this.average,
    required this.minimum,
    required this.maximum,
  });

  final int count;
  final double average;
  final double minimum;
  final double maximum;

  bool get hasData => count > 0;

  static const MetricSummary empty = MetricSummary(count: 0, average: 0, minimum: 0, maximum: 0);

  /// Folds [values] into a summary in one pass, ignoring nulls.
  factory MetricSummary.from(Iterable<double?> values) {
    var count = 0;
    var total = 0.0;
    var minimum = double.infinity;
    var maximum = double.negativeInfinity;

    for (final value in values) {
      if (value == null) continue;
      count++;
      total += value;
      if (value < minimum) minimum = value;
      if (value > maximum) maximum = value;
    }

    if (count == 0) return empty;
    return MetricSummary(count: count, average: total / count, minimum: minimum, maximum: maximum);
  }
}

/// Metadata describing one recording.
///
/// The samples themselves are deliberately *not* held here. A session is a header stored as a small
/// JSON file alongside a separate append-only stream of samples; an hour of one-second sampling is
/// 3,600 records, and keeping them in the object that gets copied on every state change is what
/// made the previous implementation quadratic. Call [RecordingStore.loadSamples] when the samples
/// are actually needed.
class RecordingSession {
  const RecordingSession({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.sampleCount = 0,
    this.intervalSeconds = 1,
    this.recoveredAfterCrash = false,
  });

  final String id;

  /// UTC. Converted to local time at the point of display.
  final DateTime startedAt;

  /// UTC. Null while the recording is still running.
  final DateTime? endedAt;

  final int sampleCount;
  final int intervalSeconds;

  /// True when this session was reconstructed from its sample stream at launch because the app was
  /// killed before it could be closed cleanly.
  final bool recoveredAfterCrash;

  bool get isActive => endedAt == null;

  /// Both operands are UTC, so this is never distorted by a timezone or DST transition.
  Duration get duration => (endedAt ?? DateTime.now().toUtc()).difference(startedAt);

  RecordingSession copyWith({DateTime? endedAt, int? sampleCount, bool? recoveredAfterCrash}) =>
      RecordingSession(
        id: id,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        sampleCount: sampleCount ?? this.sampleCount,
        intervalSeconds: intervalSeconds,
        recoveredAfterCrash: recoveredAfterCrash ?? this.recoveredAfterCrash,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    'sampleCount': sampleCount,
    'intervalSeconds': intervalSeconds,
    'recoveredAfterCrash': recoveredAfterCrash,
  };

  /// Parses a stored header, or returns null if it is unusable.
  ///
  /// A session without a readable id or start time cannot be presented or opened, so it is skipped
  /// rather than surfaced as a broken row.
  static RecordingSession? tryFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final startedAt = DateTime.tryParse(json['startedAt']?.toString() ?? '');
    if (id is! String || id.isEmpty || startedAt == null) return null;

    return RecordingSession(
      id: id,
      startedAt: startedAt,
      endedAt: DateTime.tryParse(json['endedAt']?.toString() ?? ''),
      sampleCount: (json['sampleCount'] as num?)?.toInt() ?? 0,
      intervalSeconds: (json['intervalSeconds'] as num?)?.toInt() ?? 1,
      recoveredAfterCrash: json['recoveredAfterCrash'] == true,
    );
  }
}

/// A session together with its samples and derived statistics.
class SessionDetail {
  SessionDetail({required this.session, required this.samples})
    : cpu = MetricSummary.from(samples.map((s) => s.cpuPercent)),
      deviceMemory = MetricSummary.from(samples.map((s) => s.deviceMemoryPercent)),
      appMemory = MetricSummary.from(samples.map((s) => s.appMemoryBytes?.toDouble())),
      battery = MetricSummary.from(samples.map((s) => s.batteryPercent)),
      temperature = MetricSummary.from(samples.map((s) => s.batteryTemperatureC));

  final RecordingSession session;
  final List<MetricSample> samples;

  final MetricSummary cpu;
  final MetricSummary deviceMemory;
  final MetricSummary appMemory;
  final MetricSummary battery;
  final MetricSummary temperature;

  /// True when the device reported memory pressure at any point during the session.
  bool get sawLowMemory => samples.any((s) => s.deviceLowMemory);
}
