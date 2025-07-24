import 'dart:async';
import 'package:flutter/services.dart';

class FloatingOverlayService {
  static const MethodChannel _channel = MethodChannel('floating_overlay');
  static bool _isOverlayActive = false;

  /// Check if the app has system overlay permission
  static Future<bool> hasOverlayPermission() async {
    try {
      final bool hasPermission = await _channel.invokeMethod('hasOverlayPermission');
      return hasPermission;
    } catch (e) {
      print('Error checking overlay permission: $e');
      return false;
    }
  }

  /// Request system overlay permission from user
  static Future<bool> requestOverlayPermission() async {
    try {
      final bool granted = await _channel.invokeMethod('requestOverlayPermission');
      return granted;
    } catch (e) {
      print('Error requesting overlay permission: $e');
      return false;
    }
  }

  /// Start the floating overlay
  static Future<bool> startOverlay() async {
    try {
      if (!await hasOverlayPermission()) {
        final granted = await requestOverlayPermission();
        if (!granted) return false;
      }

      final bool started = await _channel.invokeMethod('startOverlay');
      _isOverlayActive = started;
      return started;
    } catch (e) {
      print('Error starting overlay: $e');
      return false;
    }
  }

  /// Stop the floating overlay
  static Future<bool> stopOverlay() async {
    try {
      final bool stopped = await _channel.invokeMethod('stopOverlay');
      _isOverlayActive = !stopped;
      return stopped;
    } catch (e) {
      print('Error stopping overlay: $e');
      return false;
    }
  }

  /// Update overlay with new performance data
  static Future<void> updateOverlayData({
    required double cpuUsage,
    required double memoryUsage,
  }) async {
    try {
      await _channel.invokeMethod('updateOverlayData', {
        'cpuUsage': cpuUsage,
        'memoryUsage': memoryUsage,
      });
    } catch (e) {
      print('Error updating overlay data: $e');
    }
  }

  /// Check if overlay is currently active
  static bool get isOverlayActive => _isOverlayActive;

  /// Set overlay position
  static Future<void> setOverlayPosition({required double x, required double y}) async {
    try {
      await _channel.invokeMethod('setOverlayPosition', {
        'x': x,
        'y': y,
      });
    } catch (e) {
      print('Error setting overlay position: $e');
    }
  }

  /// Toggle overlay expanded/collapsed state
  static Future<void> toggleOverlayExpanded() async {
    try {
      await _channel.invokeMethod('toggleOverlayExpanded');
    } catch (e) {
      print('Error toggling overlay: $e');
    }
  }
}
