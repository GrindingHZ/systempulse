import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cpu_memory_tracking_app/models/performance_data.dart';
import 'package:cpu_memory_tracking_app/models/recording_session.dart';
import 'package:cpu_memory_tracking_app/models/device_hardware_info.dart';
import 'package:cpu_memory_tracking_app/services/notification_service.dart';
import 'package:cpu_memory_tracking_app/services/file_export_service.dart';
import 'package:cpu_memory_tracking_app/services/device_hardware_service.dart';

class PerformanceProvider extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('performance_tracker');
  
  // Notification service
  final NotificationService _notificationService = NotificationService();
  
  // File export service
  final FileExportService _fileExportService = FileExportService();

  // Hardware services
  final DeviceHardwareService _hardwareService = DeviceHardwareService();
  
  // Current performance data
  PerformanceData? _currentData;
  
  // Device hardware information
  DeviceHardwareInfo? _hardwareInfo;
  
  // Recording state
  bool _isRecording = false;
  RecordingSession? _currentSession;
  Timer? _recordingTimer;
  Timer? _liveMonitoringTimer;
  
  // Historical data
  List<RecordingSession> _sessions = [];
  
  // Recording interval in seconds
  int _recordingInterval = 1;
  
  // Chart display settings
  int _chartDurationSeconds = 60; // Default 60 seconds like Task Manager
  final List<PerformanceData> _liveChartData = [];

  // Getters
  PerformanceData? get currentData => _currentData;
  DeviceHardwareInfo? get hardwareInfo => _hardwareInfo;
  bool get isRecording => _isRecording;
  RecordingSession? get currentSession => _currentSession;
  List<RecordingSession> get sessions => List.unmodifiable(_sessions);
  int get recordingInterval => _recordingInterval;
  int get chartDurationSeconds => _chartDurationSeconds;
  List<PerformanceData> get liveChartData => List.unmodifiable(_liveChartData);
  Duration get currentRecordingDuration => 
      _currentSession?.duration ?? Duration.zero;
  NotificationService get notificationService => _notificationService;
  FileExportService get fileExportService => _fileExportService;

  // Initialize the provider
  PerformanceProvider() {
    initialize();
  }

  // Load device hardware information
  Future<void> _loadHardwareInfo() async {
    try {
      _hardwareInfo = await _hardwareService.getDeviceHardwareInfo();
      notifyListeners();
    } catch (e) {
      // Hardware info loading failed, will be null
      _hardwareInfo = null;
    }
  }

  // Initialize the provider
  Future<void> initialize() async {
    // Initialize notification service with callback
    await _notificationService.initialize(
      onStopRecording: () async {
        if (_isRecording) {
          await stopRecording();
        }
      },
    );
    
    // Load saved sessions and settings
    await _loadSessions();
    await _loadHardwareInfo();
    // Load sampling interval setting
    await _loadSamplingInterval();
    
    // Start live monitoring
    _startLiveMonitoring();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _liveMonitoringTimer?.cancel();
    super.dispose();
  }

  // Start live monitoring (always running)
  void _startLiveMonitoring() {
    _liveMonitoringTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      await _updateCurrentData();
    });
  }

  // Helper method to get performance data from platform channel
  Future<PerformanceData> _getPerformanceData() async {
    try {
      // Try to get data from platform channel first
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('getCurrentPerformance');
      
      if (result != null) {
        return PerformanceData(
          timestamp: DateTime.now(),
          cpuUsage: (result['cpuUsage'] as num?)?.toDouble() ?? 0.0,
          memoryUsage: (result['memoryUsage'] as num?)?.toDouble() ?? 0.0,
          memoryUsedMB: (result['memoryUsedMB'] as num?)?.toDouble() ?? 0.0,
          memoryTotalMB: (result['memoryTotalMB'] as num?)?.toDouble() ?? 0.0,
        );
      } else {
        // Return zero values if no data available
        return PerformanceData(
          timestamp: DateTime.now(),
          cpuUsage: 0.0,
          memoryUsage: 0.0,
          memoryUsedMB: 0.0,
          memoryTotalMB: 0.0,
        );
      }
    } catch (e) {
      // Return zero values if platform channel fails
      return PerformanceData(
        timestamp: DateTime.now(),
        cpuUsage: 0.0,
        memoryUsage: 0.0,
        memoryUsedMB: 0.0,
        memoryTotalMB: 0.0,
      );
    }
  }

  // Update current performance data
  Future<void> _updateCurrentData() async {
    print('DEBUG: Attempting to get current performance data...');
    _currentData = await _getPerformanceData();
    
    if (_currentData != null) {
      print('DEBUG: Received performance data: CPU: ${_currentData!.cpuUsage}%, Memory: ${_currentData!.memoryUsage}%');
    }
    
    // Add to live chart data (Task Manager style)
    if (_currentData != null) {
      _liveChartData.add(_currentData!);
      
      // Keep only data points within the chart duration window
      final cutoffTime = DateTime.now().subtract(Duration(seconds: _chartDurationSeconds));
      _liveChartData.removeWhere((data) => data.timestamp.isBefore(cutoffTime));
    }
    
    // Update recording notification with fresh data if recording
    if (_isRecording && _currentData != null && _currentSession != null) {
      await _updateRecordingNotification();
    }
    
    notifyListeners();
  }

  // Update recording data (separate from live monitoring)
  Future<void> _updateRecordingData() async {
    if (!_isRecording || _currentSession == null) return;
    
    // Get fresh performance data specifically for recording
    final recordingData = await _getPerformanceData();
    print('DEBUG: Collected data point - CPU: ${recordingData.cpuUsage}%, Memory: ${recordingData.memoryUsage}%');
    
    // Add to current recording session
    _currentSession = _currentSession!.copyWith(
      dataPoints: [..._currentSession!.dataPoints, recordingData],
    );
    
    print('DEBUG: Session now has ${_currentSession!.dataPoints.length} data points');

    // Update notification with fresh data
    await _updateRecordingNotification();
    
    // Only notify listeners to update the recording UI (not the live charts)
    notifyListeners();
  }

  // Start recording
  Future<void> startRecording() async {
    if (_isRecording) return;

    // Request notification permissions if not granted
    final hasPermissions = await _notificationService.areNotificationsPermitted();
    if (!hasPermissions) {
      await _notificationService.requestNotificationPermissions();
    }

    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _currentSession = RecordingSession(
      id: sessionId,
      startTime: DateTime.now(),
      dataPoints: [], // Start with empty data points, let timer handle collection
    );

    _isRecording = true;
    
    // Start recording timer based on user-defined interval (not live monitoring frequency)
    _recordingTimer = Timer.periodic(Duration(seconds: _recordingInterval), (timer) async {
      await _updateRecordingData();
    });
    
    // Collect first data point immediately
    await _updateRecordingData();
    
    // Show persistent notification with initial data
    if (_currentData != null) {
      print('DEBUG: Showing recording notification...');
      await _notificationService.showRecordingNotification(
        duration: _currentSession!.duration,
        cpuUsage: _currentData!.cpuUsage,
        memoryUsage: _currentData!.memoryUsage,
      );
    }
    
    notifyListeners();
  }

  // Stop recording and save
  Future<void> stopRecording() async {
    if (!_isRecording || _currentSession == null) return;

    print('DEBUG: Stopping recording...');
    print('DEBUG: Current session has ${_currentSession!.dataPoints.length} data points');

    _isRecording = false;
    _recordingTimer?.cancel(); // Stop the intensive recording timer
    
    final endedSession = _currentSession!.copyWith(
      endTime: DateTime.now(),
    );

    print('DEBUG: Session duration: ${endedSession.duration}');

    // Try to save to CSV, but don't fail if it doesn't work
    String? filePath;
    try {
      filePath = await _saveSessionToCsv(endedSession);
      print('DEBUG: Session saved to: $filePath');
    } catch (e) {
      print('DEBUG: Failed to save CSV (continuing anyway): $e');
      // Continue without CSV file path
    }
    
    final finalSession = endedSession.copyWith(filePath: filePath);
    
    _sessions.add(finalSession);
    print('DEBUG: Added session to list. Total sessions: ${_sessions.length}');
    _currentSession = null;
    
    try {
      await _saveSessions();
      print('DEBUG: Sessions saved to SharedPreferences');
    } catch (e) {
      print('DEBUG: Failed to save sessions: $e');
    }
    
    notifyListeners();
    
    // Hide notification
    await _notificationService.clearRecordingNotification();
  }

  // Update recording notification with current performance data
  Future<void> _updateRecordingNotification() async {
    if (_isRecording && _currentData != null && _currentSession != null) {
      await _notificationService.updateRecordingNotification(
        duration: _currentSession!.duration,
        cpuUsage: _currentData!.cpuUsage,
        memoryUsage: _currentData!.memoryUsage,
      );
    }
  }

  // Save session to CSV file using FileExportService
  Future<String> _saveSessionToCsv(RecordingSession session) async {
    try {
      // Try to save to Downloads folder first
      final result = await _fileExportService.exportToDownloads(session);
      if (result.isSuccess) {
        return result.filePath!;
      } else {
        print('DEBUG: Downloads export failed: ${result.error}');
        // Fall back to internal storage
        return await _saveToInternalStorage(session);
      }
    } catch (e) {
      print('DEBUG: Export service failed: $e');
      // Fall back to internal storage
      return await _saveToInternalStorage(session);
    }
  }

  // Fallback method to save to app's internal storage
  Future<String> _saveToInternalStorage(RecordingSession session) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'recording_${session.id}.csv';
      final file = File('${directory.path}/$fileName');
      
      // Generate simple CSV content
      final csvContent = _generateSimpleCsvContent(session);
      await file.writeAsString(csvContent);
      
      print('DEBUG: Saved to internal storage: ${file.path}');
      return file.path;
    } catch (e) {
      print('DEBUG: Internal storage save failed: $e');
      throw Exception('Failed to save recording: $e');
    }
  }

  // Generate simple CSV content for internal storage
  String _generateSimpleCsvContent(RecordingSession session) {
    final buffer = StringBuffer();
    
    // Add headers
    buffer.writeln('# SystemPulse Performance Data');
    buffer.writeln('# Session ID,${session.id}');
    buffer.writeln('# Start Time,${session.startTime.toIso8601String()}');
    buffer.writeln('# End Time,${session.endTime?.toIso8601String() ?? 'Ongoing'}');
    buffer.writeln('# Duration,${session.duration.toString()}');
    buffer.writeln('# Data Points,${session.dataPoints.length}');
    buffer.writeln('');
    
    // Add data headers
    buffer.writeln('Timestamp,CPU Usage (%),Memory Usage (%),Memory Used (MB),Memory Total (MB)');
    
    // Add data
    for (final dataPoint in session.dataPoints) {
      buffer.writeln('${dataPoint.timestamp.toIso8601String()},${dataPoint.cpuUsage.toStringAsFixed(2)},${dataPoint.memoryUsage.toStringAsFixed(2)},${dataPoint.memoryUsedMB.toStringAsFixed(0)},${dataPoint.memoryTotalMB.toStringAsFixed(0)}');
    }
    
    return buffer.toString();
  }

  // Delete a recording session
  Future<void> deleteSession(String sessionId) async {
    final sessionIndex = _sessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex == -1) return;

    final session = _sessions[sessionIndex];
    
    // Delete CSV file if it exists
    if (session.filePath != null) {
      try {
        final file = File(session.filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // File deletion failed, but continue with session removal
      }
    }

    _sessions.removeAt(sessionIndex);
    await _saveSessions();
    notifyListeners();
  }

  // Export session CSV to downloads folder
  Future<String> exportSessionCsv(String sessionId) async {
    final session = _sessions.firstWhere((s) => s.id == sessionId);
    
    // Always use the file export service for proper Downloads folder access
    final result = await _fileExportService.exportToDownloads(session);
    
    if (result.isSuccess) {
      return result.filePath!;
    } else {
      throw Exception(result.error);
    }
  }

  // Set recording interval
  // Set chart duration
  void setChartDuration(int seconds) {
    _chartDurationSeconds = seconds.clamp(30, 300); // 30 seconds to 5 minutes
    
    // Clean up existing data to match new duration
    final cutoffTime = DateTime.now().subtract(Duration(seconds: _chartDurationSeconds));
    _liveChartData.removeWhere((data) => data.timestamp.isBefore(cutoffTime));
    
    notifyListeners();
  }

  // Load sampling interval setting
  Future<void> _loadSamplingInterval() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _recordingInterval = prefs.getInt('sampling_interval') ?? 1;
    } catch (e) {
      _recordingInterval = 1; // Default to 1 second
    }
    notifyListeners();
  }

  // Set sampling interval and save to preferences
  Future<void> setSamplingInterval(int seconds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _recordingInterval = seconds.clamp(1, 60);
      await prefs.setInt('sampling_interval', _recordingInterval);
      notifyListeners();
    } catch (e) {
      // Handle save error
    }
  }

  // Get sampling interval display text
  String getSamplingIntervalText() {
    switch (_recordingInterval) {
      case 1:
        return '1 second';
      case 10:
        return '10 seconds';
      case 60:
        return '1 minute';
      default:
        return '$_recordingInterval seconds';
    }
  }

  // Load saved sessions (placeholder - would implement proper persistence)
  Future<void> _loadSessions() async {
    try {
      print('DEBUG: Loading sessions from SharedPreferences');
      final prefs = await SharedPreferences.getInstance();
      final String? sessionsJson = prefs.getString('pulse_track_sessions');
      
      if (sessionsJson != null) {
        print('DEBUG: Found sessions JSON in SharedPreferences: $sessionsJson');
        final List<dynamic> sessionsList = jsonDecode(sessionsJson);
        print('DEBUG: Decoded ${sessionsList.length} sessions');
        _sessions = sessionsList.map((sessionJson) {
          return RecordingSession.fromJson(sessionJson);
        }).toList();
        print('DEBUG: Loaded ${_sessions.length} sessions successfully');
      } else {
        print('DEBUG: No sessions found in SharedPreferences');
        _sessions = [];
      }
    } catch (e) {
      print('DEBUG: Error loading sessions: $e');
      _sessions = [];
    }
    notifyListeners();
  }

  // Save sessions (placeholder - would implement proper persistence)
  Future<void> _saveSessions() async {
    try {
      print('DEBUG: Saving ${_sessions.length} sessions to SharedPreferences');
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> sessionsJson = _sessions.map((session) {
        return session.toJson();
      }).toList();
      print('DEBUG: Sessions JSON length: ${sessionsJson.length}');
      await prefs.setString('pulse_track_sessions', jsonEncode(sessionsJson));
      print('DEBUG: Sessions saved successfully');
    } catch (e) {
      print('DEBUG: Error saving sessions: $e');
      // Handle save error
    }
  }
  
}
