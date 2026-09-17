import 'dart:math' as math;

import '../data/models/device_profile.dart';
import '../data/models/metric_sample.dart';
import '../data/sources/metrics_source.dart';

/// A [MetricsSource] that generates plausible telemetry instead of reading a device.
///
/// Used by the preview entrypoint so the interface can be rendered and reviewed on a desktop
/// browser, where no native implementation exists. It is not referenced from `main.dart` and so
/// never reaches a release build.
class ScriptedMetricsSource implements MetricsSource {
  ScriptedMetricsSource({int seed = 7}) : _random = math.Random(seed);

  final math.Random _random;
  int _tick = 0;

  @override
  Future<MetricSample> sample() async {
    _tick++;
    return MetricSample.fromMap(sampleMap(_tick, _random));
  }

  /// A single scripted reading: CPU drifting with periodic spikes, memory steady, battery draining.
  static Map<String, Object?> sampleMap(int tick, math.Random random) {
    final drift = 14 + 9 * math.sin(tick / 7);
    final spike = tick % 23 == 0 ? 34.0 : 0.0;
    final cpu = (drift + spike + random.nextDouble() * 4).clamp(0.0, 100.0);

    return <String, Object?>{
      't': DateTime.now().millisecondsSinceEpoch,
      'cpuPercent': cpu,
      'cpuPerCorePercent': cpu * 9,
      'cpuAvailable': true,
      'deviceMemoryPercent': 62 + 5 * math.sin(tick / 11),
      'deviceMemoryUsedBytes': 8100000000,
      'deviceMemoryTotalBytes': 12884901888,
      'appMemoryBytes': 148000000,
      'deviceLowMemory': false,
      'memoryAvailable': true,
      'batteryPercent': (78 - tick / 90).clamp(0.0, 100.0),
      'batteryTemperatureC': 30.5 + tick / 200,
      'batteryStatus': 'Discharging',
      'batteryCharging': false,
      'batteryAvailable': true,
    };
  }

  @override
  Future<DeviceProfile> deviceInfo() async => const DeviceProfile(
    model: 'Pixel 8 Pro',
    manufacturer: 'Google',
    board: 'husky',
    hardware: 'zuma',
    androidRelease: '15',
    sdkInt: 35,
    abis: ['arm64-v8a', 'armeabi-v7a'],
    coreCount: 9,
    maxCpuFrequencyMhz: 3300,
    totalRamBytes: 12884901888,
    screenWidthPx: 1344,
    screenHeightPx: 2992,
    screenDensityDpi: 480,
  );

  @override
  Future<bool> startRecording({required String sessionId, required int intervalSeconds}) async =>
      true;

  @override
  Future<bool> stopRecording() async => true;

  @override
  Future<String> sessionsDirectory() async => '/preview/sessions';

  @override
  Future<String?> saveToDownloads({
    required String fileName,
    required String content,
    String mimeType = 'text/csv',
  }) async => 'Downloads/$fileName';
}
