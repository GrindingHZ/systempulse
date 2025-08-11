import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cpu_memory_tracking_app/providers/performance_provider.dart';
import 'package:cpu_memory_tracking_app/providers/theme_provider.dart';
import 'package:cpu_memory_tracking_app/providers/floating_overlay_provider.dart';
import 'package:cpu_memory_tracking_app/screens/splash_screen.dart';
import 'package:cpu_memory_tracking_app/utils/theme.dart';
import 'package:cpu_memory_tracking_app/widgets/simple_performance_overlay.dart';

void main() {
  runApp(const SystemPulseApp());
}

class SystemPulseApp extends StatefulWidget {
  const SystemPulseApp({super.key});

  @override
  State<SystemPulseApp> createState() => _SystemPulseAppState();
}

class _SystemPulseAppState extends State<SystemPulseApp> {
  bool _showPerformanceOverlay = false;
  late PerformanceProvider _performanceProvider;

  @override
  void initState() {
    super.initState();
    _performanceProvider = PerformanceProvider();
    // Initialize the performance provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performanceProvider.initialize();
    });
  }

  @override
  void dispose() {
    _performanceProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PerformanceProvider>.value(value: _performanceProvider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProxyProvider<PerformanceProvider, FloatingOverlayProvider>(
          create: (context) => FloatingOverlayProvider(),
          update: (context, performanceProvider, previous) {
            if (previous != null) {
              previous.setPerformanceProvider(performanceProvider);
              return previous;
            }
            return FloatingOverlayProvider(performanceProvider: performanceProvider);
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'SystemPulse',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: SimplePerformanceOverlay(
              showMonitor: _showPerformanceOverlay,
              child: SplashScreenWrapper(
                onToggleOverlay: () {
                  setState(() {
                    _showPerformanceOverlay = !_showPerformanceOverlay;
                  });
                },
                showOverlay: _showPerformanceOverlay,
              ),
            ),
          );
        },
      ),
    );
  }
}

class SplashScreenWrapper extends StatelessWidget {
  final VoidCallback onToggleOverlay;
  final bool showOverlay;

  const SplashScreenWrapper({
    Key? key,
    required this.onToggleOverlay,
    required this.showOverlay,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SplashScreen(
      onToggleOverlay: onToggleOverlay,
      showOverlay: showOverlay,
    );
  }
}
