import 'package:flutter/cupertino.dart';

/// Semantic colours.
///
/// These are built on [CupertinoColors], which carries Apple's own light and dark values and
/// resolves against the ambient [CupertinoTheme] brightness. Deriving from the system palette
/// rather than hardcoding hex means dark mode is correct by construction instead of being a second
/// set of values to keep in sync.
///
/// Colour is used sparingly and semantically. A metric is tinted only where the tint carries
/// meaning (which metric it is, or that a threshold has been crossed); everything else is greyscale
/// so that the coloured elements actually stand out.
abstract final class Palette {
  /// The background behind grouped content. Light grey in light mode, black in dark mode, so
  /// raised surfaces read as raised in both.
  static const CupertinoDynamicColor canvas = CupertinoColors.systemGroupedBackground;

  /// A raised surface sitting on [canvas]: white on grey, dark grey on black.
  static const CupertinoDynamicColor surface = CupertinoColors.secondarySystemGroupedBackground;

  /// A surface nested inside another surface.
  static const CupertinoDynamicColor surfaceElevated =
      CupertinoColors.tertiarySystemGroupedBackground;

  /// Primary text.
  static const CupertinoDynamicColor label = CupertinoColors.label;

  /// Supporting text. Apple defines this with alpha rather than a flat grey so it stays correct
  /// over any background.
  static const CupertinoDynamicColor labelSecondary = CupertinoColors.secondaryLabel;

  /// De-emphasised text: units, captions, placeholder values.
  static const CupertinoDynamicColor labelTertiary = CupertinoColors.tertiaryLabel;

  /// Disabled or absent content.
  static const CupertinoDynamicColor labelQuaternary = CupertinoColors.quaternaryLabel;

  /// Hairline rules between rows.
  static const CupertinoDynamicColor separator = CupertinoColors.separator;

  /// The single accent colour. Interactive elements are this colour; nothing else is.
  static const CupertinoDynamicColor accent = CupertinoColors.systemBlue;

  /// Destructive actions and threshold breaches.
  static const CupertinoDynamicColor danger = CupertinoColors.systemRed;

  /// Healthy state.
  static const CupertinoDynamicColor success = CupertinoColors.systemGreen;

  /// Elevated but not yet critical.
  static const CupertinoDynamicColor warning = CupertinoColors.systemOrange;

  /// Fill for an inactive track behind a progress indicator.
  static const CupertinoDynamicColor track = CupertinoColors.systemFill;

  // --- Per-metric identity -------------------------------------------------------------------
  //
  // Each metric keeps one hue everywhere it appears — tile, chart line, legend, history row — so
  // the colour itself becomes the label and the eye can follow one series across screens.

  /// CPU.
  static const CupertinoDynamicColor cpu = CupertinoColors.systemBlue;

  /// Memory.
  static const CupertinoDynamicColor memory = CupertinoColors.systemIndigo;

  /// Battery level.
  static const CupertinoDynamicColor battery = CupertinoColors.systemGreen;

  /// Battery temperature.
  static const CupertinoDynamicColor temperature = CupertinoColors.systemOrange;

  /// Resolves [color] against the ambient theme brightness.
  static Color of(BuildContext context, Color color) =>
      CupertinoDynamicColor.resolve(color, context);

  /// The colour for a utilisation reading, used to flag a value that has climbed into a range
  /// worth noticing.
  ///
  /// Thresholds are intentionally high: a monitoring tool that turns red at moderate load trains
  /// the user to ignore it.
  static Color forLoad(BuildContext context, double percent) {
    if (percent >= 90) return of(context, danger);
    if (percent >= 75) return of(context, warning);
    return of(context, success);
  }

  /// The colour for a battery level.
  static Color forBattery(BuildContext context, double percent) {
    if (percent <= 10) return of(context, danger);
    if (percent <= 20) return of(context, warning);
    return of(context, success);
  }
}
