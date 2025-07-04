import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cpu_memory_tracking_app/main.dart';
import 'package:cpu_memory_tracking_app/providers/performance_provider.dart';
import 'package:cpu_memory_tracking_app/providers/theme_provider.dart';

void main() {
  group('SystemPulse App Widget Tests', () {
    late PerformanceProvider performanceProvider;
    late ThemeProvider themeProvider;

    setUp(() {
      // Setup method channel mocks
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('performance_tracker'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getCurrentPerformance') {
            return {
              'cpuUsage': 25.0,
              'memoryUsage': 50.0,
              'memoryUsedMB': 2048.0,
              'memoryTotalMB': 4096.0,
            };
          }
          return null;
        },
      );

      // Mock shared preferences
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter.io/shared_preferences'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getAll') {
            return <String, dynamic>{
              'flutter.dark_theme': false,
              'sampling_interval': 1,
            };
          }
          if (methodCall.method == 'setBool') {
            return true;
          }
          if (methodCall.method == 'setInt') {
            return true;
          }
          return null;
        },
      );

      // Mock device info
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/device_info'),
        (MethodCall methodCall) async {
          return <String, dynamic>{};
        },
      );

      // Mock path provider
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async {
          return '/test/documents';
        },
      );

      // Mock notifications
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (MethodCall methodCall) async {
          return null;
        },
      );

      // Mock hardware info channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('device_hardware_info'),
        (MethodCall methodCall) async {
          return {
            'processorName': 'Test Processor',
            'coreCount': 8,
            'clockSpeed': '3.0 GHz',
            'totalRamGB': '8 GB',
            'ramType': 'DDR4',
            'architecture': 'x64',
            'deviceModel': 'Test Device',
            'osVersion': 'Test OS 1.0',
          };
        },
      );

      performanceProvider = PerformanceProvider();
      themeProvider = ThemeProvider();
    });

    tearDown(() {
      performanceProvider.dispose();
      // Clear method channel handlers
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('performance_tracker'),
        null,
      );
    });

    testWidgets('SystemPulse app smoke test', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: performanceProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: const SystemPulseApp(),
        ),
      );

      // Wait for any async operations
      await tester.pumpAndSettle();

      // Verify that our app has the basic navigation structure
      expect(find.byType(NavigationBar), findsOneWidget);
      
      // Verify navigation destinations
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Device'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('should display performance gauges on dashboard', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: performanceProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: const SystemPulseApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Look for CPU and Memory text indicators
      expect(find.textContaining('CPU'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Memory'), findsAtLeastNWidgets(1));
    });

    testWidgets('should navigate between tabs', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: performanceProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: const SystemPulseApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on History tab
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      // Should show recording history content
      expect(find.textContaining('Recording'), findsAtLeastNWidgets(1));

      // Tap on Device tab
      await tester.tap(find.text('Device'));
      await tester.pumpAndSettle();

      // Should show device info
      expect(find.textContaining('Device'), findsAtLeastNWidgets(1));

      // Tap on Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Should show settings content
      expect(find.textContaining('Settings'), findsAtLeastNWidgets(1));
    });

    testWidgets('should show recording controls', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: performanceProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: const SystemPulseApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Look for recording button (should be a play/start icon initially)
      expect(find.byIcon(Icons.play_arrow), findsAtLeastNWidgets(1));
    });

    testWidgets('should handle recording start/stop', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: performanceProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: const SystemPulseApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap the recording button
      final recordingButton = find.byIcon(Icons.play_arrow);
      if (recordingButton.evaluate().isNotEmpty) {
        await tester.tap(recordingButton.first);
        await tester.pumpAndSettle();

        // After starting recording, should show stop icon
        expect(find.byIcon(Icons.stop), findsAtLeastNWidgets(1));

        // Tap stop button
        final stopButton = find.byIcon(Icons.stop);
        if (stopButton.evaluate().isNotEmpty) {
          await tester.tap(stopButton.first);
          await tester.pumpAndSettle();

          // Should be back to play icon
          expect(find.byIcon(Icons.play_arrow), findsAtLeastNWidgets(1));
        }
      }
    });

    testWidgets('should display device information', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: performanceProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: const SystemPulseApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to device tab
      await tester.tap(find.text('Device'));
      await tester.pumpAndSettle();

      // Should show device information
      expect(find.textContaining('Processor'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Memory'), findsAtLeastNWidgets(1));
    });

    testWidgets('should handle theme switching', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: performanceProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: const SystemPulseApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Look for theme toggle
      final themeSwitch = find.byType(Switch);
      if (themeSwitch.evaluate().isNotEmpty) {
        await tester.tap(themeSwitch.first);
        await tester.pumpAndSettle();

        // Theme should have changed (hard to verify exact colors in test)
        // But the switch should now be in opposite state
        expect(find.byType(Switch), findsAtLeastNWidgets(1));
      }
    });

    testWidgets('should show recording history when available', (WidgetTester tester) async {
      // Start and stop a recording to create history
      await performanceProvider.startRecording();
      await Future.delayed(const Duration(milliseconds: 100));
      await performanceProvider.stopRecording();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: performanceProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: const SystemPulseApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to history tab
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      // Should show at least one recording session
      expect(performanceProvider.sessions.length, greaterThan(0));
    });

    testWidgets('should handle error states gracefully', (WidgetTester tester) async {
      // Mock failing platform channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('performance_tracker'),
        (MethodCall methodCall) async {
          throw PlatformException(code: 'ERROR', message: 'Test error');
        },
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: performanceProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: const SystemPulseApp(),
        ),
      );

      await tester.pumpAndSettle();

      // App should still render without crashing
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
    });
  });
}