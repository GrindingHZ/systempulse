import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small, durable user preferences.
///
/// SharedPreferences is the right tool at this size — a handful of scalars. It was the wrong tool
/// for recorded samples, which now live in [RecordingStore].
class SettingsStore {
  static const String _intervalKey = 'sampling_interval_seconds';
  static const String _themeKey = 'theme_mode';
  static const String _notificationsKey = 'notifications_enabled';
  static const String _chartWindowKey = 'chart_window_seconds';

  /// Allowed sampling intervals, in seconds.
  ///
  /// The floor is one second: the platform call itself costs a few milliseconds and PSS in
  /// particular is a binder round trip, so sampling faster would measure the monitor more than the
  /// device.
  static const List<int> allowedIntervals = [1, 2, 5, 10, 30, 60];

  static const int defaultInterval = 1;
  static const int defaultChartWindow = 60;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<int> readInterval() async {
    final stored = (await _prefs).getInt(_intervalKey) ?? defaultInterval;
    // A value from an older build, or one hand-edited, must not put the recorder into a state the
    // UI cannot represent.
    return allowedIntervals.contains(stored) ? stored : defaultInterval;
  }

  Future<void> writeInterval(int seconds) async {
    if (!allowedIntervals.contains(seconds)) return;
    await (await _prefs).setInt(_intervalKey, seconds);
  }

  Future<Brightness?> readThemeOverride() async {
    switch ((await _prefs).getString(_themeKey)) {
      case 'light':
        return Brightness.light;
      case 'dark':
        return Brightness.dark;
      default:
        // Null means follow the system, which is the default and what most users expect.
        return null;
    }
  }

  /// Persists the theme choice. The previous implementation kept it in memory only, so the setting
  /// silently reverted on every launch.
  Future<void> writeThemeOverride(Brightness? brightness) async {
    final prefs = await _prefs;
    if (brightness == null) {
      await prefs.remove(_themeKey);
    } else {
      await prefs.setString(_themeKey, brightness == Brightness.dark ? 'dark' : 'light');
    }
  }

  Future<bool> readNotificationsEnabled() async =>
      (await _prefs).getBool(_notificationsKey) ?? true;

  Future<void> writeNotificationsEnabled(bool enabled) async =>
      (await _prefs).setBool(_notificationsKey, enabled);

  Future<int> readChartWindow() async =>
      (await _prefs).getInt(_chartWindowKey) ?? defaultChartWindow;

  Future<void> writeChartWindow(int seconds) async =>
      (await _prefs).setInt(_chartWindowKey, seconds.clamp(30, 600));
}
