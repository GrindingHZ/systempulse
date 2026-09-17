import 'dart:async';
import 'dart:collection';

import 'package:flutter/cupertino.dart';

import '../data/models/device_profile.dart';
import '../data/models/metric_sample.dart';
import '../data/models/recording_session.dart';
import '../data/sources/csv_exporter.dart';
import '../data/sources/metrics_channel.dart';
import '../data/sources/recording_store.dart';
import '../data/sources/settings_store.dart';

/// Why the live readout is not currently showing numbers.
enum LiveStatus {
  /// Before the first successful sample.
  starting,

  /// Sampling normally.
  live,

  /// Suspended because the app is not in the foreground. Recording, if any, continues natively.
  paused,

  /// The platform declined to supply readings.
  unavailable,
}

/// Owns live sampling, recording lifecycle and session history.
///
/// Rewritten from the previous provider, which had several defects that only appear under real use:
/// an unguarded async `Timer.periodic` that could overlap ticks, `notifyListeners` reachable after
/// `dispose`, a sampling interval that could not change until the next session, a live buffer that
/// grew without bound, and a per-tick copy of the entire sample list.
class MonitorController extends ChangeNotifier with WidgetsBindingObserver {
  MonitorController({
    required RecordingStore store,
    MetricsSource channel = const MetricsChannel(),
    SettingsStore? settings,
  }) : _store = store,
       _channel = channel,
       _settings = settings ?? SettingsStore();

  final RecordingStore _store;
  final MetricsSource _channel;
  final SettingsStore _settings;

  Timer? _liveTimer;

  /// Guards against overlapping ticks. A platform call that takes longer than the sampling
  /// interval would otherwise have a second call issued on top of it, and under sustained load
  /// those pile up until the channel is saturated.
  bool _sampleInFlight = false;

  /// Set in [dispose]. Every async continuation checks it before touching state, because a
  /// platform call in flight when the controller is torn down would otherwise call
  /// `notifyListeners` on a disposed object.
  bool _disposed = false;

  MetricSample? _latest;
  LiveStatus _status = LiveStatus.starting;
  String? _statusDetail;
  DeviceProfile? _device;

  /// Rolling window for the live chart, oldest first.
  ///
  /// A queue with an explicit cap rather than a list filtered by timestamp on every tick: the old
  /// implementation walked and rewrote the whole list once a second to drop expired entries.
  final Queue<MetricSample> _liveWindow = Queue<MetricSample>();
  int _chartWindowSeconds = SettingsStore.defaultChartWindow;

  RecordingSession? _activeSession;
  List<RecordingSession> _sessions = const [];
  int _intervalSeconds = SettingsStore.defaultInterval;
  Brightness? _themeOverride;
  List<RecordingSession> _recoveredSessions = const [];

  MetricSample? get latest => _latest;
  LiveStatus get status => _status;
  String? get statusDetail => _statusDetail;
  DeviceProfile? get device => _device;
  List<MetricSample> get liveWindow => List.unmodifiable(_liveWindow);
  bool get isRecording => _activeSession != null;
  RecordingSession? get activeSession => _activeSession;
  List<RecordingSession> get sessions => List.unmodifiable(_sessions);
  int get intervalSeconds => _intervalSeconds;
  int get chartWindowSeconds => _chartWindowSeconds;
  Brightness? get themeOverride => _themeOverride;

  /// Sessions closed out at launch after an unclean shutdown, for a one-time notice in the UI.
  List<RecordingSession> get recoveredSessions => List.unmodifiable(_recoveredSessions);

  Duration get elapsed => _activeSession?.duration ?? Duration.zero;

  /// Loads persisted state and begins live sampling.
  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);

    _intervalSeconds = await _settings.readInterval();
    _chartWindowSeconds = await _settings.readChartWindow();
    _themeOverride = await _settings.readThemeOverride();

    // Close out anything the previous run left open before listing, so the history shows a
    // finished session rather than one that appears to still be running.
    _recoveredSessions = await _store.recoverInterruptedSessions();
    _sessions = await _store.listSessions();

    unawaited(_loadDeviceProfile());
    _startLiveSampling();
    _safeNotify();
  }

  Future<void> _loadDeviceProfile() async {
    try {
      final profile = await _channel.deviceInfo();
      if (_disposed) return;
      _device = profile;
      _safeNotify();
    } on MetricsUnavailable {
      // The device screen renders whatever is known and says nothing about the rest. No values are
      // substituted.
    }
  }

  // --- Live sampling -------------------------------------------------------------------------

  void _startLiveSampling() {
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    unawaited(_tick());
  }

  void _stopLiveSampling() {
    _liveTimer?.cancel();
    _liveTimer = null;
  }

  Future<void> _tick() async {
    if (_disposed || _sampleInFlight) return;
    _sampleInFlight = true;
    try {
      final sample = await _channel.sample();
      if (_disposed) return;

      _latest = sample;
      _status = sample.hasAnyReading ? LiveStatus.live : LiveStatus.starting;
      _statusDetail = null;
      _pushToWindow(sample);
      _safeNotify();
    } on MetricsUnavailable catch (error) {
      if (_disposed) return;
      // Surfaced rather than swallowed: the UI shows "—" and the reason, instead of a zero that
      // would read as a genuine measurement.
      _status = LiveStatus.unavailable;
      _statusDetail = error.message;
      _safeNotify();
    } finally {
      _sampleInFlight = false;
    }
  }

  /// Feeds a sample straight into the live window.
  ///
  /// Exists so tests can fill the window without waiting out one real second per sample.
  @visibleForTesting
  void debugPushSample(MetricSample sample) {
    _pushToWindow(sample);
    _safeNotify();
  }

  void _pushToWindow(MetricSample sample) {
    _liveWindow.addLast(sample);
    // One sample per second, so the window length in seconds is also its capacity. Trimming from
    // the head is O(1) per removal and touches only what expired.
    while (_liveWindow.length > _chartWindowSeconds) {
      _liveWindow.removeFirst();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        if (_liveTimer == null) {
          _status = LiveStatus.starting;
          _startLiveSampling();
          _safeNotify();
        }
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Polling the platform once a second to update a UI nobody is looking at is pure battery
        // cost. An active recording is unaffected: it runs in the native foreground service.
        _stopLiveSampling();
        if (_status != LiveStatus.unavailable) {
          _status = LiveStatus.paused;
        }
    }
  }

  // --- Recording -----------------------------------------------------------------------------

  /// Starts a recording. Returns null on success, or a message describing why it could not start.
  Future<String?> startRecording() async {
    if (_activeSession != null) return null;

    final session = RecordingSession(
      id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
      startedAt: DateTime.now().toUtc(),
      intervalSeconds: _intervalSeconds,
    );

    try {
      final started = await _channel.startRecording(
        sessionId: session.id,
        intervalSeconds: _intervalSeconds,
      );
      if (!started) return 'The recording service did not start.';
    } on MetricsUnavailable catch (error) {
      return error.message;
    }

    // The header is written before any sample arrives, so an immediate crash still leaves a
    // recoverable session rather than an orphaned stream of samples with no metadata.
    await _store.saveSession(session);
    if (_disposed) return null;

    _activeSession = session;
    _sessions = [session, ..._sessions];
    _safeNotify();
    return null;
  }

  /// Stops the active recording and finalises its header.
  Future<void> stopRecording() async {
    final session = _activeSession;
    if (session == null) return;

    try {
      await _channel.stopRecording();
    } on MetricsUnavailable {
      // Even if the service could not be reached, the samples written so far are on disk and the
      // session must still be closed out — otherwise it reappears as "interrupted" at next launch.
    }

    final sampleCount = await _store.countSamples(session.id);
    final finished = session.copyWith(endedAt: DateTime.now().toUtc(), sampleCount: sampleCount);
    await _store.saveSession(finished);
    if (_disposed) return;

    _activeSession = null;
    _sessions = [
      for (final existing in _sessions)
        if (existing.id == finished.id) finished else existing,
    ];
    _safeNotify();
  }

  Future<SessionDetail> loadSession(RecordingSession session) async {
    final samples = await _store.loadSamples(session.id);
    return SessionDetail(session: session, samples: samples);
  }

  Future<void> deleteSession(String id) async {
    await _store.deleteSession(id);
    if (_disposed) return;
    _sessions = _sessions.where((session) => session.id != id).toList();
    _safeNotify();
  }

  /// Writes a session to the user's Downloads folder, returning where it landed.
  Future<String> exportSession(RecordingSession session) async {
    final samples = await _store.loadSamples(session.id);
    final csv = CsvExporter.build(session, samples);
    final location = await _channel.saveToDownloads(
      fileName: CsvExporter.fileNameFor(session),
      content: csv,
    );
    if (location == null) {
      throw const MetricsUnavailable('The file could not be written.');
    }
    return location;
  }

  /// Clears the one-time recovery notice once it has been shown.
  void acknowledgeRecovery() {
    if (_recoveredSessions.isEmpty) return;
    _recoveredSessions = const [];
    _safeNotify();
  }

  // --- Settings ------------------------------------------------------------------------------

  /// Changes the sampling interval.
  ///
  /// Applied to a recording already in progress by restarting the native sampler, rather than
  /// taking effect only at the next session as it previously did — a setting that appears to change
  /// nothing is worse than no setting.
  Future<void> setInterval(int seconds) async {
    if (!SettingsStore.allowedIntervals.contains(seconds)) return;
    if (seconds == _intervalSeconds) return;

    _intervalSeconds = seconds;
    await _settings.writeInterval(seconds);
    if (_disposed) return;

    final session = _activeSession;
    if (session != null) {
      try {
        await _channel.stopRecording();
        await _channel.startRecording(sessionId: session.id, intervalSeconds: seconds);
      } on MetricsUnavailable {
        // The recording continues at the previous interval; the stored preference still applies to
        // the next session.
      }
    }
    _safeNotify();
  }

  Future<void> setChartWindow(int seconds) async {
    _chartWindowSeconds = seconds.clamp(30, 600);
    await _settings.writeChartWindow(_chartWindowSeconds);
    if (_disposed) return;
    while (_liveWindow.length > _chartWindowSeconds) {
      _liveWindow.removeFirst();
    }
    _safeNotify();
  }

  Future<void> setThemeOverride(Brightness? brightness) async {
    _themeOverride = brightness;
    await _settings.writeThemeOverride(brightness);
    if (_disposed) return;
    _safeNotify();
  }

  /// Notifies listeners unless the controller has been torn down.
  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopLiveSampling();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
