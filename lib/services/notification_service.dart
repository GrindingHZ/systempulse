import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  static const String _notificationEnabledKey = 'notifications_enabled';
  static const int _recordingNotificationId = 1001;
  static const String _stopRecordingActionId = 'stop_recording';

  bool _isInitialized = false;
  VoidCallback? _onStopRecordingCallback;

  /// Initialize the notification service
  Future<void> initialize({VoidCallback? onStopRecording}) async {
    if (_isInitialized) return;

    _onStopRecordingCallback = onStopRecording;

    // Android initialization
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS initialization
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // Don't auto-request
      requestBadgePermission: false, // Don't auto-request
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
    );

    _isInitialized = true;

    // Don't automatically request permissions on initialization
    // Let the user explicitly enable notifications in settings
  }

  /// Handle notification response
  static void _onNotificationResponse(NotificationResponse response) {
    final instance = NotificationService._instance;
    if (response.actionId == _stopRecordingActionId) {
      instance._onStopRecordingCallback?.call();
    }
  }

  /// Handle background notification response
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    _onNotificationResponse(response);
  }

  /// Show persistent recording notification
  Future<void> showRecordingNotification({
    required Duration duration,
    required double cpuUsage,
    required double memoryUsage,
  }) async {
    if (!_isInitialized || !await isNotificationEnabled()) return;

    final durationText = _formatDuration(duration);
    
    // Android notification details
    final androidDetails = AndroidNotificationDetails(
      'recording_channel',
      'Recording Notifications',
      channelDescription: 'Notifications shown during performance recording',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true, // Makes notification persistent
      autoCancel: false, // Prevents dismissing by swiping
      showWhen: false,
      enableVibration: false,
      playSound: false,
      category: AndroidNotificationCategory.progress,
      visibility: NotificationVisibility.public,
      actions: [
        const AndroidNotificationAction(
          _stopRecordingActionId,
          'Stop Recording',
          icon: DrawableResourceAndroidBitmap('@drawable/ic_stop'),
          contextual: true,
        ),
      ],
      styleInformation: BigTextStyleInformation(
        'CPU: ${cpuUsage.toStringAsFixed(1)}% • Memory: ${memoryUsage.toStringAsFixed(1)}%\nTap to open app or use "Stop Recording" to end session.',
        htmlFormatBigText: false,
        contentTitle: 'SystemPulse - Recording ($durationText)',
        htmlFormatContentTitle: false,
        summaryText: 'Performance monitoring active',
        htmlFormatSummaryText: false,
      ),
    );

    // iOS notification details
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
      interruptionLevel: InterruptionLevel.passive,
      categoryIdentifier: 'RECORDING_CATEGORY',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _recordingNotificationId,
      'SystemPulse - Recording ($durationText)',
      'CPU: ${cpuUsage.toStringAsFixed(1)}% • Memory: ${memoryUsage.toStringAsFixed(1)}%',
      details,
    );
  }

  /// Update the recording notification with new data
  Future<void> updateRecordingNotification({
    required Duration duration,
    required double cpuUsage,
    required double memoryUsage,
  }) async {
    // Just call show again with the same ID to update
    await showRecordingNotification(
      duration: duration,
      cpuUsage: cpuUsage,
      memoryUsage: memoryUsage,
    );
  }

  /// Clear the recording notification
  Future<void> clearRecordingNotification() async {
    await _notifications.cancel(_recordingNotificationId);
  }

  /// Show a general notification to the user
  Future<void> showGeneralNotification(String title, String body) async {
    if (!_isInitialized) return;
    
    final enabled = await isNotificationEnabled();
    if (!enabled) return;

    const androidDetails = AndroidNotificationDetails(
      'general',
      'General Notifications',
      channelDescription: 'General app notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use a unique ID for general notifications
    final notificationId = DateTime.now().millisecondsSinceEpoch % 1000000;
    
    await _notifications.show(
      notificationId,
      title,
      body,
      details,
    );
  }

  /// Check if notifications are enabled
  Future<bool> isNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationEnabledKey) ?? true; // Default to enabled
  }

  /// Set notification preference
  Future<void> setNotificationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationEnabledKey, enabled);
    
    // If disabled while recording, clear the notification
    if (!enabled) {
      await clearRecordingNotification();
    }
  }

  /// Check if notification permissions are granted
  Future<bool> areNotificationsPermitted() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.areNotificationsEnabled();
        return granted ?? false;
      }
    } else if (Platform.isIOS) {
      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final granted = await iosPlugin.checkPermissions();
        return granted?.isEnabled ?? false;
      }
    }
    return false;
  }

  /// Request notification permissions if not granted
  Future<bool> requestNotificationPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        // Request exact alarm permission for Android 12+
        await androidPlugin.requestExactAlarmsPermission();
        
        // Request notification permission for Android 13+
        final granted = await androidPlugin.requestNotificationsPermission();
        return granted ?? false;
      }
    } else if (Platform.isIOS) {
      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      
      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: false,
        );
        return granted ?? false;
      }
    }
    return true;
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}
