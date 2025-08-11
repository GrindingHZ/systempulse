import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'performance_provider.dart';

class FloatingOverlayProvider extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('floating_overlay');
  
  bool _isOverlayActive = false;
  Timer? _updateTimer;
  PerformanceProvider? _performanceProvider;

  bool get isOverlayActive => _isOverlayActive;

  void setPerformanceProvider(PerformanceProvider provider) {
    _performanceProvider = provider;
  }

  Future<bool> toggleOverlay() async {
    if (_isOverlayActive) {
      return await stopOverlay();
    } else {
      return await startOverlay();
    }
  }

  Future<bool> startOverlay() async {
    try {
      final started = await _channel.invokeMethod('startOverlay');
      if (started) {
        _isOverlayActive = true;
        _startDataUpdates();
        notifyListeners();
      }
      return started;
    } catch (e) {
      // debugPrint('Error starting overlay: $e');
      return false;
    }
  }

  Future<bool> stopOverlay() async {
    try {
      final stopped = await _channel.invokeMethod('stopOverlay');
      if (stopped) {
        _isOverlayActive = false;
        _stopDataUpdates();
        notifyListeners();
      }
      return stopped;
    } catch (e) {
      // debugPrint('Error stopping overlay: $e');
      return false;
    }
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

  Future<void> _updateOverlayData() async {
    if (!_isOverlayActive || _performanceProvider == null) return;

    try {
      final currentData = _performanceProvider!.currentData;
      if (currentData != null) {
        await _channel.invokeMethod('updateOverlayData', {
          'cpuUsage': currentData.cpuUsage,
          'memoryUsage': currentData.memoryUsage,
        });
      }
    } catch (e) {
      // debugPrint('Error updating overlay data: $e');
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
}
