import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:greensheart_app/features/system_monitor/domain/models/system_performance_data.dart';
import 'package:greensheart_app/features/system_monitor/domain/models/system_recording_session.dart';
import 'package:greensheart_app/features/system_monitor/data/services/system_file_export_service.dart';

class SystemMonitorProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel('system_performance_tracker');
  
  // Services
  final SystemFileExportService _fileExportService = SystemFileExportService();
  
  // Current performance data
  SystemPerformanceData? _currentData;
  
  // Recording state
  bool _isRecording = false;
  SystemRecordingSession? _currentSession;
  Timer? _recordingTimer;
  Timer? _liveMonitoringTimer;
  bool _hasAutoSaved = false; // Flag to prevent duplicate saves
  
  // Auto-save interval for active recording sessions
  Timer? _autoSaveTimer;
  static const Duration _autoSaveInterval = Duration(seconds: 10);
  
  // Historical data
  List<SystemRecordingSession> _sessions = [];
  
  // Recording interval in seconds
  int _recordingInterval = 60;
  
  // Chart display settings
  int _chartDurationSeconds = 600; // Default 600 seconds
  final List<SystemPerformanceData> _liveChartData = [];

  // Getters
  SystemPerformanceData? get currentData => _currentData;
  bool get isRecording => _isRecording;
  SystemRecordingSession? get currentSession => _currentSession;
  List<SystemRecordingSession> get sessions => List.unmodifiable(_sessions);
  int get recordingInterval => _recordingInterval;
  int get chartDurationSeconds => _chartDurationSeconds;
  List<SystemPerformanceData> get liveChartData => List.unmodifiable(_liveChartData);
  Duration get currentRecordingDuration => 
      _currentSession?.duration ?? Duration.zero;
  SystemFileExportService get fileExportService => _fileExportService;
  
  // Check if there are any interrupted/recovered sessions
  bool get hasInterruptedSessions => 
      _sessions.any((session) => session.endTime == null);

  // Initialize the provider
  SystemMonitorProvider() {
    initialize();
  }

  // Initialize the provider
  Future<void> initialize() async {
    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    
    // Load saved sessions and settings
    await _loadSessions();
    // Load sampling interval setting
    await _loadSamplingInterval();
    
    // Check for and resume incomplete recording session
    await _checkAndResumeIncompleteSession();
    
    // Start live monitoring
    _startLiveMonitoring();
  }

  @override
  void dispose() {
    // Only perform auto-save if we haven't already saved and we're still recording
    if (_isRecording && !_hasAutoSaved) {
      _autoSaveCurrentRecording();
    }
    
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _liveMonitoringTimer?.cancel();
    _autoSaveTimer?.cancel();
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        // App backgrounded - continue recording normally, no auto-save
        break;
      case AppLifecycleState.detached:
        // App being killed - perform auto-save
        _handleAppKilled();
        break;
      case AppLifecycleState.resumed:
        // App resumed from background
        break;
      case AppLifecycleState.inactive:
        // App transitioning - do nothing, let it transition normally
        break;
      case AppLifecycleState.hidden:
        // App hidden but not killed - continue recording
        break;
    }
  }

  // Handle app being killed/terminated - this is the ONLY time we auto-save
  void _handleAppKilled() async {
    await _autoSaveCurrentRecording();
  }

  // Emergency auto-save current recording without stopping it (only on app kill)
  Future<void> _autoSaveCurrentRecording() async {
    if (!_isRecording || _currentSession == null || _hasAutoSaved) return;
    
    // Set flag to prevent duplicate saves
    _hasAutoSaved = true;
    
    try {
      // Create a snapshot of the current session with end time
      final snapshot = _currentSession!.copyWith(
        endTime: DateTime.now(), // Mark current time as end for the snapshot
        id: '${_currentSession!.id}_autosave_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      // Remove from incomplete sessions and add to completed sessions
      await _removeIncompleteSession(_currentSession!.id);
      _sessions.insert(0, snapshot);
      
      // Save sessions immediately
      await _saveSessions();
      
      print('🔄 Emergency auto-save completed successfully');
      
    } catch (e) {
      print('❌ Critical emergency auto-save error: $e');
    }
  }

  // Start live monitoring (always running)
  void _startLiveMonitoring() {
    _liveMonitoringTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      await _updateCurrentData();
    });
  }

  // Helper method to get performance data from platform channel
  Future<SystemPerformanceData> _getPerformanceData() async {
    try {
      // Try to get data from platform channel first
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('getCurrentPerformance');
      
      if (result != null) {
        return SystemPerformanceData(
          timestamp: DateTime.now(),
          cpuUsage: (result['cpuUsage'] as num?)?.toDouble() ?? 0.0,
          memoryUsage: (result['memoryUsage'] as num?)?.toDouble() ?? 0.0,
          memoryUsedMB: (result['memoryUsedMB'] as num?)?.toDouble() ?? 0.0,
          memoryTotalMB: (result['memoryTotalMB'] as num?)?.toDouble() ?? 0.0,
        );
      } else {
        // Return zero values if no data available
        return SystemPerformanceData(
          timestamp: DateTime.now(),
          cpuUsage: 0.0,
          memoryUsage: 0.0,
          memoryUsedMB: 0.0,
          memoryTotalMB: 0.0,
        );
      }
    } catch (e) {
      // Return zero values if platform channel fails
      return SystemPerformanceData(
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
    final newData = await _getPerformanceData();
    _currentData = newData;
    
    // Add to live chart data
    _liveChartData.add(newData);
    
    // Keep only the last N seconds of data for the chart
    final cutoffTime = DateTime.now().subtract(Duration(seconds: _chartDurationSeconds));
    _liveChartData.removeWhere((data) => data.timestamp.isBefore(cutoffTime));
    
    notifyListeners();
  }

  // Start recording performance data
  Future<void> startRecording() async {
    if (_isRecording) return;
    
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _currentSession = SystemRecordingSession(
      id: sessionId,
      startTime: DateTime.now(),
      dataPoints: [],
    );
    
    _isRecording = true;
    _hasAutoSaved = false; // Reset flag for new recording
    
    // Save the initial session (marks it as in-progress)
    await _saveIncompleteSession(_currentSession!);
    
    // Start recording timer
    _recordingTimer = Timer.periodic(Duration(seconds: _recordingInterval), (timer) async {
      if (_isRecording && _currentSession != null) {
        final data = await _getPerformanceData();
        _currentSession = _currentSession!.copyWith(
          dataPoints: [..._currentSession!.dataPoints, data],
        );
        notifyListeners();
      }
    });
    
    // Start auto-save timer to periodically save progress
    _autoSaveTimer = Timer.periodic(_autoSaveInterval, (timer) async {
      if (_isRecording && _currentSession != null) {
        await _saveIncompleteSession(_currentSession!);
      }
    });
    
    notifyListeners();
  }

  // Stop recording performance data
  Future<void> stopRecording() async {
    if (!_isRecording || _currentSession == null) return;
    
    // Set flag to indicate we're saving normally
    _hasAutoSaved = true;
    
    _recordingTimer?.cancel();
    _autoSaveTimer?.cancel();
    _isRecording = false;
    
    // Finalize the session
    _currentSession = _currentSession!.copyWith(endTime: DateTime.now());
    
    // Remove from incomplete sessions and add to completed sessions
    await _removeIncompleteSession(_currentSession!.id);
    _sessions.insert(0, _currentSession!);
    
    // Save sessions
    await _saveSessions();
    
    _currentSession = null;
    notifyListeners();
  }

  // Delete a recording session
  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((session) => session.id == sessionId);
    await _saveSessions();
    notifyListeners();
  }

  // Update recording interval
  Future<void> updateRecordingInterval(int intervalSeconds) async {
    _recordingInterval = intervalSeconds;
    await _saveSamplingInterval();
    
    // If currently recording, restart the timer with new interval
    if (_isRecording) {
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(Duration(seconds: _recordingInterval), (timer) async {
        if (_isRecording && _currentSession != null) {
          final data = await _getPerformanceData();
          _currentSession = _currentSession!.copyWith(
            dataPoints: [..._currentSession!.dataPoints, data],
          );
          notifyListeners();
        }
      });
      
      // Restart auto-save timer as well
      _autoSaveTimer?.cancel();
      _autoSaveTimer = Timer.periodic(_autoSaveInterval, (timer) async {
        if (_isRecording && _currentSession != null) {
          await _saveIncompleteSession(_currentSession!);
        }
      });
    }
    
    notifyListeners();
  }

  // Update chart duration
  void updateChartDuration(int durationSeconds) {
    _chartDurationSeconds = durationSeconds;
    
    // Remove old data points from live chart
    final cutoffTime = DateTime.now().subtract(Duration(seconds: _chartDurationSeconds));
    _liveChartData.removeWhere((data) => data.timestamp.isBefore(cutoffTime));
    
    notifyListeners();
  }

  // Load sessions from shared preferences
  Future<void> _loadSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = prefs.getStringList('system_monitor_sessions') ?? [];
      
      _sessions = sessionsJson
          .map((json) => SystemRecordingSession.fromJson(jsonDecode(json)))
          .toList();
      
      // Sort by start time (newest first)
      _sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
      
      notifyListeners();
    } catch (e) {
      print('❌ Failed to load sessions: $e');
      _sessions = [];
    }
  }

  // Save sessions to shared preferences
  Future<void> _saveSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = _sessions
          .map((session) => jsonEncode(session.toJson()))
          .toList();
      
      await prefs.setStringList('system_monitor_sessions', sessionsJson);
    } catch (e) {
      print('❌ Failed to save sessions: $e');
    }
  }

  // Load sampling interval from shared preferences
  Future<void> _loadSamplingInterval() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _recordingInterval = prefs.getInt('system_monitor_sampling_interval') ?? 1;
    } catch (e) {
      print('❌ Failed to load sampling interval: $e');
      _recordingInterval = 1;
    }
  }

  // Save sampling interval to shared preferences
  Future<void> _saveSamplingInterval() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('system_monitor_sampling_interval', _recordingInterval);
    } catch (e) {
      print('❌ Failed to save sampling interval: $e');
    }
  }

  // Check for and resume incomplete recording session
  Future<void> _checkAndResumeIncompleteSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final incompleteSessionJson = prefs.getString('system_monitor_incomplete_session');
      
      if (incompleteSessionJson != null) {
        final incompleteSession = SystemRecordingSession.fromJson(jsonDecode(incompleteSessionJson));
        
        // Calculate how long ago this session started
        final timeSinceStart = DateTime.now().difference(incompleteSession.startTime);
        
        print('📱 Found incomplete recording session from ${incompleteSession.startTime}');
        print('📱 Session was interrupted after ${timeSinceStart.inMinutes} minutes');
        
        // Finalize the incomplete session with the last known timestamp
        final lastDataPoint = incompleteSession.dataPoints.isNotEmpty 
            ? incompleteSession.dataPoints.last.timestamp 
            : incompleteSession.startTime;
            
        final finalizedSession = incompleteSession.copyWith(
          endTime: lastDataPoint,
        );
        
        // Add to completed sessions
        _sessions.insert(0, finalizedSession);
        await _saveSessions();
        
        // Remove the incomplete session
        await _removeIncompleteSession(incompleteSession.id);
        
        print('📱 Recovered ${incompleteSession.dataPoints.length} data points from interrupted session');
        notifyListeners();
      }
    } catch (e) {
      print('❌ Failed to check for incomplete session: $e');
    }
  }

  // Save incomplete session progress
  Future<void> _saveIncompleteSession(SystemRecordingSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('system_monitor_incomplete_session', jsonEncode(session.toJson()));
    } catch (e) {
      print('❌ Failed to save incomplete session: $e');
    }
  }

  // Remove incomplete session
  Future<void> _removeIncompleteSession(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('system_monitor_incomplete_session');
    } catch (e) {
      print('❌ Failed to remove incomplete session: $e');
    }
  }
}
