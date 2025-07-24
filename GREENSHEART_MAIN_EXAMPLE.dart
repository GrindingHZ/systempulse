// main.dart for greensheart_app with SystemPulse integration

import 'package:flutter/material.dart';
import 'package:system_pulse_monitor/system_pulse_monitor.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Greensheart App',
      home: SystemPulseWrapper(
        child: YourExistingGreensheartHomePage(), // Replace with your actual home page
      ),
    );
  }
}

// If you want to access performance data in your greensheart_app widgets:
class PerformanceMonitorWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<PerformanceProvider>(
      builder: (context, performance, child) {
        final data = performance.currentData;
        if (data == null) {
          return Text('Loading performance data...');
        }
        
        return Column(
          children: [
            Text('CPU Usage: ${data.cpuUsage.toStringAsFixed(1)}%'),
            Text('Memory Usage: ${data.memoryUsage.toStringAsFixed(1)}%'),
          ],
        );
      },
    );
  }
}
