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

class PerformanceProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel('performance_tracker');
  
  final NotificationService _notificationService = NotificationService();
  final FileExportService _fileExportService = FileExportService();
  final DeviceHardwareService _hardwareService = DeviceHardwareService();
  
  PerformanceData? _currentData;
  DeviceHardwareInfo? _hardwareInfo;
  
  bool _isRecording = false;
  RecordingSession? _currentSession;
  Timer? _recordingTimer;
  Timer? _liveMonitoringTimer;
  bool _hasAutoSaved = false;
  
  List<RecordingSession> _sessions = [];
  int _recordingInterval = 1;
  int _chartDurationSeconds = 60;
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
  Duration get currentRecordingDuration => _currentSession?.duration ?? Duration.zero;
  NotificationService get notificationService => _notificationService;
  FileExportService get fileExportService => _fileExportService;

  PerformanceProvider() {
    initialize();
  }

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    
    await _notificationService.initialize(
      onStopRecording: () async {
        if (_isRecording) await stopRecording();
      },
    );
    
    await Future.wait([
      _loadSessions(),
      _loadHardwareInfo(),
      _loadSamplingInterval(),
    ]);
    
    _startLiveMonitoring();
    await _restoreRecordingState();
  }

  Future<void> _loadHardwareInfo() async {
    try {
      _hardwareInfo = await _hardwareService.getDeviceHardwareInfo();
      notifyListeners();
    } catch (e) {
      _hardwareInfo = null;
    }
  }

  @override
  void dispose() {
    // Note: Don't perform auto-save here as _handleAppKilled() already handles it
    // via AppLifecycleState.detached which triggers earlier and more reliably
    
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _liveMonitoringTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.detached) {
      _handleAppKilled();
    }
  }

  void _handleAppKilled() {
    if (_isRecording && _currentSession != null && !_hasAutoSaved) {
      _hasAutoSaved = true;
      _performImmediateAutoSave();
    }
  }

  void _performImmediateAutoSave() {
    try {
      final snapshot = _currentSession!.copyWith(
        endTime: DateTime.now(),
        id: '${_currentSession!.id}_autosave_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      _sessions.insert(0, snapshot);
      _saveSessionsImmediately();
      
      // Note: Don't show notification here as the app is being killed
      // The notification will be shown on next app restart in _restoreRecordingState
    } catch (e) {
      // Silent fail for emergency save
    }
  }

  void _saveSessionsImmediately() {
    _saveSessions().catchError((_) {});
  }

  Future<void> _saveRecordingState() async {
    if (!_isRecording || _currentSession == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final state = {
        'isRecording': true,
        'sessionJson': _currentSession!.toJson(),
      };
      
      await prefs.setString('recording_state', jsonEncode(state));
    } catch (e) {
      // Silent fail
    }
  }

  // Restore recording state after app restart
  Future<void> _restoreRecordingState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateJson = prefs.getString('recording_state');
      
      if (stateJson != null) {
        final state = jsonDecode(stateJson) as Map<String, dynamic>;
        final isRecording = state['isRecording'] as bool? ?? false;
        
        if (isRecording && state.containsKey('sessionJson')) {
          final session = RecordingSession.fromJson(state['sessionJson'] as Map<String, dynamic>);
          final recoveredSession = session.copyWith(
            endTime: session.dataPoints.isNotEmpty ? session.dataPoints.last.timestamp : session.startTime,
            id: '${session.id}_autosave_${DateTime.now().millisecondsSinceEpoch}',
          );
          _sessions.insert(0, recoveredSession);
          await _saveSessions();
          await _clearRecordingState();
          
          // Show notification on app restart - this is more reliable than during app kill
          await _notificationService.showGeneralNotification(
            'Recording Recovered',
            'Previous recording session was automatically saved with ${recoveredSession.dataPoints.length} data points',
          );
        }
      }
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _clearRecordingState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('recording_state');
    } catch (e) {
      // Silent fail
    }
  }

  void _startLiveMonitoring() {
    _liveMonitoringTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      await _updateCurrentData();
    });
  }

  Future<PerformanceData> _getPerformanceData() async {
    try {
      final result = await _channel.invokeMethod('getCurrentPerformance');
      
      if (result != null && result is Map) {
        return PerformanceData(
          timestamp: DateTime.now(),
          cpuUsage: (result['cpuUsage'] as num?)?.toDouble() ?? 0.0,
          memoryUsage: (result['memoryUsage'] as num?)?.toDouble() ?? 0.0,
          memoryUsedMB: (result['memoryUsedMB'] as num?)?.toDouble() ?? 0.0,
          memoryTotalMB: (result['memoryTotalMB'] as num?)?.toDouble() ?? 0.0,
        );
      }
    } catch (e) {
      // Silent fail, return zero data
    }
    
    return PerformanceData(
      timestamp: DateTime.now(),
      cpuUsage: 0.0,
      memoryUsage: 0.0,
      memoryUsedMB: 0.0,
      memoryTotalMB: 0.0,
    );
  }

  Future<void> _updateCurrentData() async {
    _currentData = await _getPerformanceData();
    
    if (_currentData != null) {
      _liveChartData.add(_currentData!);
      
      // Keep only data within chart duration
      final cutoffTime = DateTime.now().subtract(Duration(seconds: _chartDurationSeconds));
      _liveChartData.removeWhere((data) => data.timestamp.isBefore(cutoffTime));
      
      // Update recording notification if recording
      if (_isRecording && _currentSession != null) {
        await _updateRecordingNotification();
      }
    }
    
    notifyListeners();
  }

  Future<void> _updateRecordingData() async {
    if (!_isRecording || _currentSession == null) return;
    
    final recordingData = await _getPerformanceData();
    
    _currentSession = _currentSession!.copyWith(
      dataPoints: [..._currentSession!.dataPoints, recordingData],
    );

    await _updateRecordingNotification();
    notifyListeners();
  }

  Future<void> startRecording() async {
    if (_isRecording) return;

    final hasPermissions = await _notificationService.areNotificationsPermitted();
    if (!hasPermissions) {
      await _notificationService.requestNotificationPermissions();
    }

    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _currentSession = RecordingSession(
      id: sessionId,
      startTime: DateTime.now(),
      dataPoints: [],
    );

    _isRecording = true;
    _hasAutoSaved = false;
    
    _recordingTimer = Timer.periodic(Duration(seconds: _recordingInterval), (timer) async {
      await _updateRecordingData();
      await _saveRecordingState(); // Save state periodically
    });
    
    // Collect first data point immediately
    await _updateRecordingData();
    
    // Show initial notification
    if (_currentData != null) {
      await _notificationService.showRecordingNotification(
        duration: _currentSession!.duration,
        cpuUsage: _currentData!.cpuUsage,
        memoryUsage: _currentData!.memoryUsage,
      );
    }
    
    notifyListeners();
  }

  Future<void> stopRecording() async {
    if (!_isRecording || _currentSession == null) return;

    _hasAutoSaved = true;
    _isRecording = false;
    _recordingTimer?.cancel();
    
    final endedSession = _currentSession!.copyWith(endTime: DateTime.now());

    String? filePath;
    try {
      filePath = await _saveSessionToCsv(endedSession);
    } catch (e) {
      // Continue without CSV file path
    }
    
    final finalSession = endedSession.copyWith(filePath: filePath);
    _sessions.add(finalSession);
    _currentSession = null;
    
    try {
      await _saveSessions();
    } catch (e) {
      // Silent fail
    }
    
    await _clearRecordingState();
    notifyListeners();
    await _notificationService.clearRecordingNotification();
  }

  Future<void> _updateRecordingNotification() async {
    if (_isRecording && _currentData != null && _currentSession != null) {
      await _notificationService.updateRecordingNotification(
        duration: _currentSession!.duration,
        cpuUsage: _currentData!.cpuUsage,
        memoryUsage: _currentData!.memoryUsage,
      );
    }
  }

  Future<String> _saveSessionToCsv(RecordingSession session) async {
    final result = await _fileExportService.exportToDownloads(session);
    if (result.isSuccess) {
      return result.filePath!;
    }
    return await _saveToInternalStorage(session);
  }

  Future<String> _saveToInternalStorage(RecordingSession session) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'recording_${session.id}.csv';
    final file = File('${directory.path}/$fileName');
    
    final csvContent = _generateCsvContent(session);
    await file.writeAsString(csvContent);
    return file.path;
  }

  String _generateCsvContent(RecordingSession session) {
    final buffer = StringBuffer()
      ..writeln('# SystemPulse Performance Data')
      ..writeln('# Session ID,${session.id}')
      ..writeln('# Start Time,${session.startTime.toIso8601String()}')
      ..writeln('# End Time,${session.endTime?.toIso8601String() ?? 'Ongoing'}')
      ..writeln('# Duration,${session.duration.toString()}')
      ..writeln('# Data Points,${session.dataPoints.length}')
      ..writeln('')
      ..writeln('Timestamp,CPU Usage (%),Memory Usage (%),Memory Used (MB),Memory Total (MB)');
    
    for (final dataPoint in session.dataPoints) {
      buffer.writeln([
        dataPoint.timestamp.toIso8601String(),
        dataPoint.cpuUsage.toStringAsFixed(2),
        dataPoint.memoryUsage.toStringAsFixed(2),
        dataPoint.memoryUsedMB.toStringAsFixed(0),
        dataPoint.memoryTotalMB.toStringAsFixed(0),
      ].join(','));
    }
    
    return buffer.toString();
  }

  Future<void> deleteSession(String sessionId) async {
    final sessionIndex = _sessions.indexWhere((s) => s.id == sessionId);
    if (sessionIndex == -1) return;

    final session = _sessions[sessionIndex];
    
    // Delete CSV file if it exists
    if (session.filePath != null) {
      try {
        final file = File(session.filePath!);
        if (await file.exists()) await file.delete();
      } catch (e) {
        // Silent fail
      }
    }

    _sessions.removeAt(sessionIndex);
    await _saveSessions();
    notifyListeners();
  }

  Future<String> exportSessionCsv(String sessionId) async {
    final session = _sessions.firstWhere((s) => s.id == sessionId);
    final result = await _fileExportService.exportToDownloads(session);
    
    if (result.isSuccess) {
      return result.filePath!;
    } else {
      throw Exception(result.error);
    }
  }

  void setChartDuration(int seconds) {
    _chartDurationSeconds = seconds.clamp(30, 300);
    
    final cutoffTime = DateTime.now().subtract(Duration(seconds: _chartDurationSeconds));
    _liveChartData.removeWhere((data) => data.timestamp.isBefore(cutoffTime));
    
    notifyListeners();
  }

  Future<void> _loadSamplingInterval() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _recordingInterval = prefs.getInt('sampling_interval') ?? 1;
    } catch (e) {
      _recordingInterval = 1;
    }
  }

  Future<void> setSamplingInterval(int seconds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _recordingInterval = seconds.clamp(1, 60);
      await prefs.setInt('sampling_interval', _recordingInterval);
      notifyListeners();
    } catch (e) {
      // Silent fail
    }
  }

  String getSamplingIntervalText() {
    switch (_recordingInterval) {
      case 1: return '1 second';
      case 10: return '10 seconds';
      case 60: return '1 minute';
      default: return '$_recordingInterval seconds';
    }
  }

  Future<void> _loadSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = prefs.getString('pulse_track_sessions');
      
      if (sessionsJson != null) {
        final sessionsList = jsonDecode(sessionsJson) as List<dynamic>;
        _sessions = sessionsList.map((sessionJson) => RecordingSession.fromJson(sessionJson)).toList();
      }
    } catch (e) {
      _sessions = [];
    }
  }

  Future<void> _saveSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = _sessions.map((session) => session.toJson()).toList();
      await prefs.setString('pulse_track_sessions', jsonEncode(sessionsJson));
    } catch (e) {
      // Silent fail
    }
  }
}
