import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';

import '../app.dart';
import '../data/sources/recording_store.dart';
import '../state/monitor_controller.dart';
import 'scripted_metrics_source.dart';

/// Preview entrypoint: runs the real interface against scripted telemetry.
///
/// Exists so the UI can be rendered and reviewed on a desktop browser, with real fonts and real
/// scroll behaviour, without an Android device in the loop:
///
///   flutter run -d chrome -t lib/dev/preview_main.dart
///   flutter build web -t lib/dev/preview_main.dart
///
/// `main.dart` is the only entrypoint a release build uses, so nothing here ships.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = MonitorController(
    store: RecordingStore(await _previewDirectory()),
    channel: ScriptedMetricsSource(),
  );

  unawaited(controller.initialize());
  runApp(SystemPulseApp(controller: controller));
}

/// A scratch directory for preview recordings.
///
/// Falls back to the system temp directory because the platform documents directory is not
/// resolvable on every desktop host, and the preview should still run there.
Future<Directory> _previewDirectory() async {
  try {
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}/preview_sessions');
  } on Object {
    return Directory('${Directory.systemTemp.path}/systempulse_preview');
  }
}
