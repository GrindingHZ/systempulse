import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:systempulse/data/models/metric_sample.dart';
import 'package:systempulse/data/models/recording_session.dart';
import 'package:systempulse/data/sources/metrics_channel.dart';
import 'package:systempulse/data/sources/recording_store.dart';
import 'package:systempulse/state/monitor_controller.dart';

/// A scripted method channel, so the controller can be exercised without a device.
class _FakeChannel {
  final MethodChannel channel = const MethodChannel('test/metrics');

  int sampleCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;
  int? lastInterval;
  Duration sampleDelay = Duration.zero;
  bool failSampling = false;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        switch (call.method) {
          case 'sample':
            sampleCalls++;
            if (sampleDelay > Duration.zero) await Future<void>.delayed(sampleDelay);
            if (failSampling) {
              throw PlatformException(code: 'UNAVAILABLE', message: 'no reading');
            }
            return <String, Object?>{
              't': DateTime.now().millisecondsSinceEpoch,
              'cpuPercent': 12.0,
              'cpuAvailable': true,
              'deviceMemoryPercent': 70.0,
              'memoryAvailable': true,
              'batteryPercent': 80.0,
              'batteryAvailable': true,
            };
          case 'startRecording':
            startCalls++;
            lastInterval = (call.arguments as Map)['intervalSeconds'] as int?;
            return true;
          case 'stopRecording':
            stopCalls++;
            return true;
          case 'deviceInfo':
            return <String, Object?>{'deviceModel': 'Test', 'coreCount': 8};
          case 'sessionsDirectory':
            return '/tmp';
          default:
            return null;
        }
      },
    );
  }

  void remove() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late RecordingStore store;
  late _FakeChannel fake;
  late MonitorController controller;
  var disposed = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('systempulse_controller');
    store = RecordingStore(directory);
    fake = _FakeChannel()..install();
    controller = MonitorController(store: store, channel: MetricsChannel(fake.channel));
    disposed = false;
  });

  tearDown(() async {
    if (!disposed) controller.dispose();
    fake.remove();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('a failed platform call surfaces as unavailable, not as a zero reading', () async {
    fake.failSampling = true;
    await controller.initialize();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(controller.status, LiveStatus.unavailable);
    expect(controller.statusDetail, 'no reading');
    // No fabricated sample is published, so nothing downstream can mistake failure for idle.
    expect(controller.latest, isNull);
  });

  test('a successful sample becomes the live reading', () async {
    await controller.initialize();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(controller.status, LiveStatus.live);
    expect(controller.latest?.cpuPercent, 12.0);
    expect(controller.liveWindow, isNotEmpty);
  });

  test('overlapping ticks are suppressed while a sample is in flight', () async {
    // Previously a new platform call was issued every second regardless of whether the last had
    // returned, so a slow device accumulated concurrent calls until the channel saturated.
    fake.sampleDelay = const Duration(milliseconds: 500);
    await controller.initialize();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(fake.sampleCalls, 1);
  });

  test('starting a recording writes a header before any sample arrives', () async {
    await controller.initialize();
    final error = await controller.startRecording();

    expect(error, isNull);
    expect(controller.isRecording, isTrue);
    expect(fake.startCalls, 1);

    final stored = await store.listSessions();
    expect(stored, hasLength(1));
    expect(stored.first.isActive, isTrue);
  });

  test('a refused start is reported and leaves no active session', () async {
    await controller.initialize();
    fake.remove();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      fake.channel,
      (call) async {
        if (call.method == 'startRecording') {
          throw PlatformException(code: 'DENIED', message: 'notifications are disabled');
        }
        return null;
      },
    );

    final error = await controller.startRecording();

    expect(error, 'notifications are disabled');
    expect(controller.isRecording, isFalse);
  });

  test('stopping finalises the header with the real sample count', () async {
    await controller.initialize();
    await controller.startRecording();
    final id = controller.activeSession!.id;

    await store.appendSample(id, MetricSample(timestamp: DateTime.now().toUtc()));
    await store.appendSample(id, MetricSample(timestamp: DateTime.now().toUtc()));

    await controller.stopRecording();

    expect(controller.isRecording, isFalse);
    expect(fake.stopCalls, 1);

    final stored = await store.listSessions();
    expect(stored.first.isActive, isFalse);
    expect(stored.first.sampleCount, 2);
  });

  test('changing the interval mid-recording restarts native sampling', () async {
    // Previously the new interval was ignored until the next session, so the setting appeared to
    // do nothing at all.
    await controller.initialize();
    await controller.startRecording();
    expect(fake.lastInterval, 1);

    await controller.setInterval(10);

    expect(controller.intervalSeconds, 10);
    expect(fake.stopCalls, 1);
    expect(fake.startCalls, 2);
    expect(fake.lastInterval, 10);
  });

  test('an unsupported interval is rejected', () async {
    await controller.initialize();
    await controller.setInterval(7);
    expect(controller.intervalSeconds, 1);
  });

  test('the live window is bounded by the chart window', () async {
    await controller.initialize();
    await controller.setChartWindow(30);

    for (var i = 0; i < 100; i++) {
      controller.debugPushSample(MetricSample(timestamp: DateTime.now().toUtc(), cpuPercent: 1));
    }

    // Unbounded growth over a long session was a leak in the previous implementation.
    expect(controller.liveWindow.length, lessThanOrEqualTo(30));
  });

  test('theme choice survives a restart', () async {
    await controller.initialize();
    await controller.setThemeOverride(Brightness.dark);

    final reloaded = MonitorController(store: store, channel: MetricsChannel(fake.channel));
    await reloaded.initialize();

    // Previously the theme lived in memory only and silently reset on every launch.
    expect(reloaded.themeOverride, Brightness.dark);
    reloaded.dispose();
  });

  test('a sample returning after disposal does not notify a dead controller', () async {
    fake.sampleDelay = const Duration(milliseconds: 400);
    await controller.initialize();

    var notified = false;
    controller.addListener(() => notified = true);
    controller.dispose();
    disposed = true;
    notified = false;

    // The in-flight call completes after disposal. Notifying here would throw
    // "A ChangeNotifier was used after being disposed".
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(notified, isFalse);
  });

  test('sessions recovered at launch are exposed once and then cleared', () async {
    // Simulates the app being killed mid-recording: a header still marked active, with samples
    // already on disk beside it.
    await store.saveSession(RecordingSession(id: 'orphan', startedAt: DateTime.utc(2026, 1, 1)));
    await store.appendSample('orphan', MetricSample(timestamp: DateTime.utc(2026, 1, 1, 0, 0, 5)));

    await controller.initialize();

    expect(controller.recoveredSessions, hasLength(1));
    expect(controller.recoveredSessions.first.recoveredAfterCrash, isTrue);
    expect(controller.recoveredSessions.first.sampleCount, 1);

    controller.acknowledgeRecovery();
    expect(controller.recoveredSessions, isEmpty);
  });
}
