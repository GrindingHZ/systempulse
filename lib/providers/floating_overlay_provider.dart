import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cpu_memory_tracking_app/services/floating_overlay_service.dart';
import 'package:cpu_memory_tracking_app/providers/performance_provider.dart';

class FloatingOverlayProvider extends ChangeNotifier {
  bool _isOverlayActive = false;
  bool _hasPermission = false;
  Timer? _updateTimer;
  PerformanceProvider? _performanceProvider;

  bool get isOverlayActive => _isOverlayActive;
  bool get hasPermission => _hasPermission;

  FloatingOverlayProvider({PerformanceProvider? performanceProvider}) {
    _performanceProvider = performanceProvider;
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    _hasPermission = await FloatingOverlayService.hasOverlayPermission();
    notifyListeners();
  }

  Future<bool> requestPermission() async {
    final granted = await FloatingOverlayService.requestOverlayPermission();
    _hasPermission = granted;
    notifyListeners();
    return granted;
  }

  Future<bool> startOverlay() async {
    if (!_hasPermission) {
      final granted = await requestPermission();
      if (!granted) return false;
    }

    final started = await FloatingOverlayService.startOverlay();
    if (started) {
      _isOverlayActive = true;
      _startDataUpdates();
      notifyListeners();
    }
    return started;
  }

  Future<bool> stopOverlay() async {
    final stopped = await FloatingOverlayService.stopOverlay();
    if (stopped) {
      _isOverlayActive = false;
      _stopDataUpdates();
      notifyListeners();
    }
    return stopped;
  }

  void _startDataUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateOverlayData();
    });
  }

  void _stopDataUpdates() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  void _updateOverlayData() {
    final currentData = _performanceProvider?.currentData;
    if (currentData != null) {
      print('DEBUG: Updating overlay with CPU: ${currentData.cpuUsage}%, Memory: ${currentData.memoryUsage}%');
      FloatingOverlayService.updateOverlayData(
        cpuUsage: currentData.cpuUsage,
        memoryUsage: currentData.memoryUsage,
      );
    } else {
      print('DEBUG: No current performance data available for overlay');
    }
  }

  Future<void> toggleOverlay() async {
    if (_isOverlayActive) {
      await stopOverlay();
    } else {
      await startOverlay();
    }
  }

  Future<void> setPosition(double x, double y) async {
    await FloatingOverlayService.setOverlayPosition(x: x, y: y);
  }

  Future<void> toggleExpanded() async {
    await FloatingOverlayService.toggleOverlayExpanded();
  }

  void setPerformanceProvider(PerformanceProvider performanceProvider) {
    _performanceProvider = performanceProvider;
  }

  @override
  void dispose() {
    _stopDataUpdates();
    if (_isOverlayActive) {
      FloatingOverlayService.stopOverlay();
    }
    super.dispose();
  }
}
