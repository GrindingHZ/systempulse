@Tags(['golden'])
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:systempulse/app.dart';
import 'package:systempulse/data/models/metric_sample.dart';
import 'package:systempulse/data/models/recording_session.dart';
import 'package:systempulse/data/sources/metrics_channel.dart';
import 'package:systempulse/data/sources/recording_store.dart';
import 'package:systempulse/state/monitor_controller.dart';

import 'font_loader.dart';

/// Renders the real screens against scripted data and writes reference images.
///
/// These exist so the interface can be reviewed as pixels rather than as code. Run with
/// `flutter test --update-goldens --tags golden` to regenerate.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestFonts);

  late Directory directory;
  late MonitorController controller;

  const channel = MethodChannel('golden/metrics');
  final random = math.Random(7);
  var tick = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('systempulse_golden');
    tick = 0;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        switch (call.method) {
          case 'sample':
            tick++;
            return _scriptedSample(tick, random);
          case 'deviceInfo':
            return <String, Object?>{
              'deviceModel': 'Pixel 8 Pro',
              'manufacturer': 'Google',
              'board': 'husky',
              'hardware': 'zuma',
              'androidRelease': '15',
              'sdkInt': 35,
              'abis': ['arm64-v8a', 'armeabi-v7a'],
              'coreCount': 9,
              'maxCpuFrequencyMhz': 3300,
              'totalRamBytes': 12884901888,
              'screenWidthPx': 1344,
              'screenHeightPx': 2992,
              'screenDensityDpi': 480,
            };
          default:
            return null;
        }
      },
    );

    controller = MonitorController(
      store: RecordingStore(directory),
      channel: const MetricsChannel(channel),
    );
  });

  tearDown(() async {
    controller.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  Future<void> renderApp(WidgetTester tester, Brightness brightness) async {
    tester.view
      ..physicalSize = const Size(1179, 2556) // iPhone 15 Pro
      ..devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // initialize() touches the filesystem. testWidgets runs the body inside a fake-async zone
    // where real dart:io futures never complete, so it has to run in the real zone.
    await tester.runAsync(() async {
      await controller.initialize();
      await controller.setThemeOverride(brightness);
    });

    // Fill the live chart so the sparklines have something to draw.
    for (var i = 0; i < 60; i++) {
      controller.debugPushSample(MetricSample.fromMap(_scriptedSample(i, random)));
    }

    await tester.pumpWidget(SystemPulseApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('dashboard, light', (tester) async {
    await renderApp(tester, Brightness.light);
    await expectLater(find.byType(SystemPulseApp), matchesGoldenFile('images/dashboard_light.png'));
  });

  testWidgets('dashboard, dark', (tester) async {
    await renderApp(tester, Brightness.dark);
    await expectLater(find.byType(SystemPulseApp), matchesGoldenFile('images/dashboard_dark.png'));
  });

  testWidgets('dashboard while recording', (tester) async {
    await renderApp(tester, Brightness.light);
    await tester.runAsync(() => controller.startRecording());
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(SystemPulseApp),
      matchesGoldenFile('images/dashboard_recording.png'),
    );
  });

  testWidgets('device screen', (tester) async {
    await renderApp(tester, Brightness.light);
    await tester.tap(find.text('Device'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(SystemPulseApp), matchesGoldenFile('images/device.png'));
  });

  testWidgets('settings screen', (tester) async {
    await renderApp(tester, Brightness.light);
    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(SystemPulseApp), matchesGoldenFile('images/settings.png'));
  });

  testWidgets('recordings list', (tester) async {
    await renderApp(tester, Brightness.light);

    await tester.runAsync(() async {
      final store = RecordingStore(directory);
      for (var i = 0; i < 3; i++) {
        await store.saveSession(
          RecordingSession(
            id: 'rec_$i',
            startedAt: DateTime.utc(2026, 9, 14 + i, 9, 30),
            endedAt: DateTime.utc(2026, 9, 14 + i, 10, 12),
            sampleCount: 2520,
            intervalSeconds: 1,
            recoveredAfterCrash: i == 1,
          ),
        );
      }
      await controller.initialize();
    });

    await tester.tap(find.text('Recordings'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(SystemPulseApp), matchesGoldenFile('images/recordings.png'));
  });
}

/// A plausible telemetry stream: CPU drifting with occasional spikes, memory steady, battery
/// slowly draining.
Map<String, Object?> _scriptedSample(int tick, math.Random random) {
  final base = 14 + 9 * math.sin(tick / 7);
  final spike = tick % 23 == 0 ? 34.0 : 0.0;
  final cpu = (base + spike + random.nextDouble() * 4).clamp(0.0, 100.0);

  return <String, Object?>{
    't': DateTime.utc(2026, 9, 17, 14, 30).add(Duration(seconds: tick)).millisecondsSinceEpoch,
    'cpuPercent': cpu,
    'cpuPerCorePercent': cpu * 9,
    'cpuAvailable': true,
    'deviceMemoryPercent': 62 + 5 * math.sin(tick / 11),
    'deviceMemoryUsedBytes': 8100000000,
    'deviceMemoryTotalBytes': 12884901888,
    'appMemoryBytes': 148000000,
    'deviceLowMemory': false,
    'memoryAvailable': true,
    'batteryPercent': 78 - tick / 90,
    'batteryTemperatureC': 30.5 + tick / 200,
    'batteryStatus': 'Discharging',
    'batteryCharging': false,
    'batteryAvailable': true,
  };
}
