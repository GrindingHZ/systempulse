import '../models/device_profile.dart';
import '../models/metric_sample.dart';

/// Raised when metrics cannot be obtained.
///
/// Errors surface as exceptions rather than being swallowed into a zeroed sample, so callers can
/// tell "the device reports 0%" apart from "we failed to ask".
class MetricsUnavailable implements Exception {
  const MetricsUnavailable(this.message);

  final String message;

  @override
  String toString() => 'MetricsUnavailable: $message';
}

/// Where telemetry comes from.
///
/// An interface rather than a concrete channel for two reasons. It lets the controller be tested
/// without standing up a mock platform channel, and it makes the "no native implementation"
/// case — desktop, web, the preview harness — an explicit implementation rather than a stream of
/// caught exceptions.
abstract interface class MetricsSource {
  /// One live reading.
  Future<MetricSample> sample();

  /// Hardware facts. These do not change, so callers may read them once.
  Future<DeviceProfile> deviceInfo();

  /// Begins a recording that continues while the UI is backgrounded.
  Future<bool> startRecording({required String sessionId, required int intervalSeconds});

  Future<bool> stopRecording();

  /// Absolute path of the directory holding recorded sample streams.
  Future<String> sessionsDirectory();

  /// Writes [content] to the user's Downloads collection.
  ///
  /// Returns a user-presentable location, or null if the platform declined.
  Future<String?> saveToDownloads({
    required String fileName,
    required String content,
    String mimeType,
  });
}
