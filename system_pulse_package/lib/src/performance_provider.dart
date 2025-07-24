import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'performance_data.dart';

class PerformanceProvider extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('performance_tracker');
  
  PerformanceData? _currentData;
  Timer? _monitoringTimer;

  PerformanceData? get currentData => _currentData;

  PerformanceProvider() {
    startMonitoring();
  }

  Future<void> startMonitoring() async {
    if (_monitoringTimer?.isActive == true) return;
    
    await _collectPerformanceData();
    _monitoringTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      await _collectPerformanceData();
    });
  }

  Future<void> stopMonitoring() async {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }

  Future<void> _collectPerformanceData() async {
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod('getPerformanceData');
      _currentData = PerformanceData.fromMap(Map<String, dynamic>.from(result));
      notifyListeners();
    } catch (e) {
      debugPrint('Error collecting performance data: $e');
    }
  }

  @override
  void dispose() {
    _monitoringTimer?.cancel();
    super.dispose();
  }
}
