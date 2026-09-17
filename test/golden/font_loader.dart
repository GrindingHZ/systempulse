import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registers real fonts for golden rendering.
///
/// The widget-test environment ships no font data, so by default every glyph renders as a filled
/// rectangle. That is fine for asserting layout but useless for reviewing typography — and this
/// design leans on exact sizes, weights and tracking, which boxes cannot show.
///
/// Roboto is loaded from the Flutter SDK's bundled copy and registered under the family names the
/// Cupertino theme asks for, so the golden images show the real type scale.
Future<void> loadTestFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Flutter selects the right face from each file's own weight metadata, so the whole set is
  // registered under one family and the theme's w400/w500/w600/w700 all resolve.
  const faces = [
    'Roboto-Light.ttf',
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ];

  final directory = Directory(_robotoDirectory);
  if (!directory.existsSync()) return;

  // CupertinoTextThemeData resolves to these families. Registering the same faces under each means
  // the goldens render with real glyphs whichever one the platform default resolves to.
  // The Cupertino text styles do not name a family, so text falls back to whatever the engine
  // treats as default — in the test environment, the box-drawing 'Ahem'. Registering the real
  // faces under that name as well is what actually puts glyphs on screen; the others cover the
  // families Cupertino resolves to on a real device.
  for (final family in [
    'Roboto',
    'Ahem',
    'FlutterTest',
    '.SF Pro Text',
    '.SF Pro Display',
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
  ]) {
    final loader = FontLoader(family);
    var loaded = false;

    for (final face in faces) {
      final file = File('$_robotoDirectory/$face');
      if (!file.existsSync()) continue;
      loader.addFont(Future<ByteData>.value(file.readAsBytesSync().buffer.asByteData()));
      loaded = true;
    }

    if (loaded) await loader.load();
  }
}

const String _robotoDirectory =
    '/opt/fl/flutter/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/Roboto';
