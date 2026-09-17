import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/sources/metrics_channel.dart';
import 'data/sources/recording_store.dart';
import 'state/monitor_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = RecordingStore(await _resolveSessionsDirectory());
  final controller = MonitorController(store: store);

  // Not awaited on purpose: initialize reads settings from disk and recovers interrupted sessions,
  // and the app should paint immediately rather than hold a blank screen until that finishes. The
  // controller notifies listeners as each piece lands.
  unawaited(controller.initialize());

  runApp(SystemPulseApp(controller: controller));
}

/// Resolves the directory holding recorded sample streams.
///
/// The path must be asked of the platform rather than derived here. The native recording service
/// appends to `context.filesDir/sessions`, while `getApplicationDocumentsDirectory()` on Android
/// returns `app_flutter` — a *different* directory. Guessing would leave Dart reading an empty
/// folder while samples accumulated somewhere else.
Future<Directory> _resolveSessionsDirectory() async {
  try {
    final path = await const MetricsChannel().sessionsDirectory();
    return Directory(path);
  } on MetricsUnavailable {
    // No native implementation — desktop, web or a test host. Recording is unavailable there, but
    // a valid directory keeps the history screen and the store functional.
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}/sessions');
  }
}
