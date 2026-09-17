import 'dart:convert';

/// One instant of measured telemetry.
///
/// Every metric carries an explicit availability flag. This matters more than it looks: the
/// previous implementation caught all platform errors and substituted zero, so a CSV row reading
/// `0.00` could mean the device was idle *or* that the reading failed entirely, with no way to tell
/// them apart after the fact. Here an unavailable metric is null, and null survives into the export.
class MetricSample {
  const MetricSample({
    required this.timestamp,
    this.cpuPercent,
    this.cpuPerCorePercent,
    this.deviceMemoryPercent,
    this.deviceMemoryUsedBytes,
    this.deviceMemoryTotalBytes,
    this.appMemoryBytes,
    this.deviceLowMemory = false,
    this.batteryPercent,
    this.batteryTemperatureC,
    this.batteryStatus,
    this.batteryCharging,
  });

  /// When the reading was taken, in UTC, from the platform clock at sample time.
  final DateTime timestamp;

  /// Share of total device CPU capacity used by this process, 0-100.
  ///
  /// Null when the platform could not supply a reading, or during the first interval of a session
  /// where there is no previous measurement to difference against.
  final double? cpuPercent;

  /// The same measurement against a single core, so 100 means one core fully busy and 400 means
  /// four. Null under the same conditions as [cpuPercent].
  final double? cpuPerCorePercent;

  /// Share of physical RAM in use device-wide, 0-100.
  ///
  /// Linux counts reclaimable page cache as used, so a healthy device sits high here. Treat
  /// [deviceLowMemory] as the pressure signal, not this number.
  final double? deviceMemoryPercent;

  final int? deviceMemoryUsedBytes;
  final int? deviceMemoryTotalBytes;

  /// This process's proportional set size in bytes — the figure Android uses to compare app
  /// footprints.
  final int? appMemoryBytes;

  /// Set when the system reports it is under memory pressure.
  final bool deviceLowMemory;

  final double? batteryPercent;
  final double? batteryTemperatureC;
  final String? batteryStatus;
  final bool? batteryCharging;

  /// True when at least one metric in this sample carries a real reading.
  bool get hasAnyReading =>
      cpuPercent != null || deviceMemoryPercent != null || batteryPercent != null;

  /// Builds a sample from the platform channel's map or from a stored JSON line.
  ///
  /// The two share a schema deliberately, so a live reading and a recorded one decode through the
  /// same path and cannot drift apart.
  factory MetricSample.fromMap(Map<dynamic, dynamic> map) {
    double? readDouble(String key, String availabilityKey) {
      if (map[availabilityKey] == false) return null;
      final value = map[key];
      return value is num ? value.toDouble() : null;
    }

    int? readInt(String key, String availabilityKey) {
      if (map[availabilityKey] == false) return null;
      final value = map[key];
      return value is num ? value.toInt() : null;
    }

    final millis = map['t'];
    return MetricSample(
      // Decoded as UTC. Timestamps are stored and exported in UTC and converted to local time only
      // for display: an ISO-8601 string without a zone designator is ambiguous to whoever opens
      // the CSV, and a recording that spans a daylight-saving change would otherwise contain
      // timestamps that go backwards.
      timestamp:
          millis is num
              ? DateTime.fromMillisecondsSinceEpoch(millis.toInt(), isUtc: true)
              : DateTime.now().toUtc(),
      cpuPercent: readDouble('cpuPercent', 'cpuAvailable'),
      cpuPerCorePercent: readDouble('cpuPerCorePercent', 'cpuAvailable'),
      deviceMemoryPercent: readDouble('deviceMemoryPercent', 'memoryAvailable'),
      deviceMemoryUsedBytes: readInt('deviceMemoryUsedBytes', 'memoryAvailable'),
      deviceMemoryTotalBytes: readInt('deviceMemoryTotalBytes', 'memoryAvailable'),
      appMemoryBytes: readInt('appMemoryBytes', 'memoryAvailable'),
      deviceLowMemory: map['deviceLowMemory'] == true,
      batteryPercent: readDouble('batteryPercent', 'batteryAvailable'),
      batteryTemperatureC: readDouble('batteryTemperatureC', 'batteryAvailable'),
      batteryStatus: map['batteryAvailable'] == false ? null : map['batteryStatus'] as String?,
      batteryCharging: map['batteryAvailable'] == false ? null : map['batteryCharging'] as bool?,
    );
  }

  /// Decodes one JSON Lines record, or null if the line is empty or corrupt.
  ///
  /// A truncated final line is expected after a process kill, so a parse failure returns null
  /// rather than throwing and discarding the whole session.
  static MetricSample? tryDecodeLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) return null;
      return MetricSample.fromMap(decoded);
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    't': timestamp.millisecondsSinceEpoch,
    'cpuPercent': cpuPercent,
    'cpuPerCorePercent': cpuPerCorePercent,
    'cpuAvailable': cpuPercent != null,
    'deviceMemoryPercent': deviceMemoryPercent,
    'deviceMemoryUsedBytes': deviceMemoryUsedBytes,
    'deviceMemoryTotalBytes': deviceMemoryTotalBytes,
    'appMemoryBytes': appMemoryBytes,
    'deviceLowMemory': deviceLowMemory,
    'memoryAvailable': deviceMemoryPercent != null,
    'batteryPercent': batteryPercent,
    'batteryTemperatureC': batteryTemperatureC,
    'batteryStatus': batteryStatus,
    'batteryCharging': batteryCharging,
    'batteryAvailable': batteryPercent != null,
  };
}
