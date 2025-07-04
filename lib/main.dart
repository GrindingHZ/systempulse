import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cpu_memory_tracking_app/providers/performance_provider.dart';
import 'package:cpu_memory_tracking_app/providers/theme_provider.dart';
import 'package:cpu_memory_tracking_app/screens/splash_screen.dart';
import 'package:cpu_memory_tracking_app/utils/theme.dart';

void main() {
  runApp(const SystemPulseApp());
}

class SystemPulseApp extends StatelessWidget {
  const SystemPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PerformanceProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'SystemPulse',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
