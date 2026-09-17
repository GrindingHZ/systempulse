import 'package:flutter/services.dart';

import '../models/device_profile.dart';
import '../models/metric_sample.dart';
import 'metrics_source.dart';

export 'metrics_source.dart' show MetricsSource, MetricsUnavailable;

/// The single channel to the native metrics implementation.
///
/// Replaces five channels (three of which carried byte-identical handlers) with one.
class MetricsChannel implements MetricsSource {
  const MetricsChannel([this._channel = _defaultChannel]);

  static const MethodChannel _defaultChannel = MethodChannel('com.systempulse.monitor/metrics');

  final MethodChannel _channel;

  /// Takes one live reading.
  @override
  Future<MetricSample> sample() async {
    final result = await _invoke<Map<dynamic, dynamic>>('sample');
    return MetricSample.fromMap(result);
  }

  /// Reads hardware facts. Cheap enough to call once at launch; values do not change.
  @override
  Future<DeviceProfile> deviceInfo() async {
    final result = await _invoke<Map<dynamic, dynamic>>('deviceInfo');
    return DeviceProfile.fromMap(result);
  }

  /// Asks the platform to begin a foreground recording that survives the UI being backgrounded.
  @override
  Future<bool> startRecording({required String sessionId, required int intervalSeconds}) async {
    final started = await _invoke<bool>('startRecording', {
      'sessionId': sessionId,
      'intervalSeconds': intervalSeconds,
    });
    return started;
  }

  @override
  Future<bool> stopRecording() => _invoke<bool>('stopRecording');

  /// Absolute path of the directory holding recorded sample streams.
  @override
  Future<String> sessionsDirectory() => _invoke<String>('sessionsDirectory');

  /// Writes [content] to the user's Downloads collection via MediaStore.
  ///
  /// Returns a user-presentable location, or null if the platform declined to write.
  @override
  Future<String?> saveToDownloads({
    required String fileName,
    required String content,
    String mimeType = 'text/csv',
  }) async {
    try {
      return await _channel.invokeMethod<String>('saveToDownloads', {
        'fileName': fileName,
        'content': content,
        'mimeType': mimeType,
      });
    } on PlatformException catch (error) {
      throw MetricsUnavailable(error.message ?? 'Could not save the file.');
    } on MissingPluginException {
      throw const MetricsUnavailable('Saving is not supported on this platform.');
    }
  }

  Future<T> _invoke<T>(String method, [Map<String, dynamic>? arguments]) async {
    try {
      final result = await _channel.invokeMethod<T>(method, arguments);
      if (result == null) {
        throw MetricsUnavailable('$method returned no value.');
      }
      return result;
    } on PlatformException catch (error) {
      throw MetricsUnavailable(error.message ?? 'Platform call $method failed.');
    } on MissingPluginException {
      // Reached on desktop and web, where no native implementation is registered.
      throw MetricsUnavailable('$method is not available on this platform.');
    }
  }
}
