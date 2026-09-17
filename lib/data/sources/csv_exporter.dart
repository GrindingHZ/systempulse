import '../models/metric_sample.dart';
import '../models/recording_session.dart';

/// Renders a session as RFC 4180 CSV.
///
/// Two things the previous implementation got wrong are fixed here.
///
/// Fields are escaped. The old exporter joined values with commas directly, so any field
/// containing a comma, quote or newline silently shifted every later column in that row. Battery
/// status is a platform-supplied string, which makes that a real risk rather than a theoretical one.
///
/// Missing readings are written as empty fields, not as `0.00`. A spreadsheet reading a blank cell
/// treats it as no data and leaves it out of averages; a zero is counted as a measurement. Writing
/// zeros for failed reads systematically drags every average downward.
abstract final class CsvExporter {
  static const List<String> _headers = [
    'timestamp_iso8601',
    'cpu_percent_of_device',
    'cpu_percent_of_one_core',
    'device_memory_percent',
    'device_memory_used_bytes',
    'device_memory_total_bytes',
    'app_memory_pss_bytes',
    'device_low_memory',
    'battery_percent',
    'battery_temperature_c',
    'battery_status',
    'battery_charging',
  ];

  /// Builds the full CSV document for [session] and [samples].
  ///
  /// Metadata is emitted as `#`-prefixed comment lines before the header row. Spreadsheet software
  /// treats them as ordinary rows, so they are kept to a minimum and placed above the header where
  /// they are easy to strip.
  static String build(RecordingSession session, List<MetricSample> samples) {
    final buffer =
        StringBuffer()
          ..writeln('# SystemPulse recording')
          ..writeln('# session_id,${_escape(session.id)}')
          ..writeln('# started_at,${session.startedAt.toIso8601String()}')
          ..writeln('# ended_at,${session.endedAt?.toIso8601String() ?? ''}')
          ..writeln('# duration_seconds,${session.duration.inSeconds}')
          ..writeln('# sample_interval_seconds,${session.intervalSeconds}')
          ..writeln('# sample_count,${samples.length}')
          // Stated explicitly because "CPU %" is ambiguous on a multi-core device, and because the
          // same column name meant something entirely different in older exports from this app.
          ..writeln('# cpu_percent_of_device: process CPU time / (elapsed time * core count)')
          ..writeln('# empty field: the device did not report a value for that sample')
          ..writeln(_headers.join(','));

    for (final sample in samples) {
      buffer.writeln(_row(sample));
    }

    return buffer.toString();
  }

  static String _row(MetricSample sample) => [
    sample.timestamp.toIso8601String(),
    _number(sample.cpuPercent, 2),
    _number(sample.cpuPerCorePercent, 2),
    _number(sample.deviceMemoryPercent, 2),
    _integer(sample.deviceMemoryUsedBytes),
    _integer(sample.deviceMemoryTotalBytes),
    _integer(sample.appMemoryBytes),
    sample.deviceLowMemory ? 'true' : 'false',
    _number(sample.batteryPercent, 1),
    _number(sample.batteryTemperatureC, 1),
    _escape(sample.batteryStatus ?? ''),
    sample.batteryCharging == null ? '' : '${sample.batteryCharging}',
  ].join(',');

  static String _number(double? value, int decimals) =>
      value == null ? '' : value.toStringAsFixed(decimals);

  static String _integer(int? value) => value?.toString() ?? '';

  /// Quotes a field when RFC 4180 requires it, doubling any embedded quotes.
  static String _escape(String value) {
    final needsQuoting =
        value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r');
    if (!needsQuoting) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  /// A filesystem-safe file name for this session.
  static String fileNameFor(RecordingSession session) {
    // Colons are legal in an ISO timestamp but not in a file name on every platform the export may
    // eventually land on.
    final stamp = session.startedAt.toIso8601String().split('.').first.replaceAll(':', '-');
    return 'SystemPulse_$stamp.csv';
  }
}
