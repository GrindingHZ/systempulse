import 'package:flutter/cupertino.dart';

/// The iOS Dynamic Type scale.
///
/// Sizes, weights, line heights and tracking follow Apple's text styles at the default ("Large")
/// content size. Using the real scale rather than invented numbers is most of what makes text feel
/// native: the ratios between headline, body and footnote are what the eye reads as hierarchy.
///
/// Tracking is negative at display sizes and positive at caption sizes. This is deliberate in
/// Apple's design — large text needs tightening to avoid looking loose, small text needs opening up
/// to stay legible — and skipping it is a common reason a typeface set at the right sizes still
/// looks wrong.
///
/// Sizes are expressed in logical pixels and scale with the user's Dynamic Type setting through
/// [MediaQuery.textScalerOf], which Flutter applies automatically.
abstract final class AppText {
  /// 34pt Bold. The collapsing screen title. One per screen, at the top.
  static const TextStyle largeTitle = TextStyle(
    fontSize: 34,
    height: 41 / 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.05,
  );

  /// 28pt Bold. A major heading inside a screen.
  static const TextStyle title1 = TextStyle(
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
  );

  /// 22pt Bold. A section heading.
  static const TextStyle title2 = TextStyle(
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.7,
  );

  /// 20pt Semibold.
  static const TextStyle title3 = TextStyle(
    fontSize: 20,
    height: 25 / 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
  );

  /// 17pt Semibold. Body text that needs emphasis — the primary line of a list row.
  static const TextStyle headline = TextStyle(
    fontSize: 17,
    height: 22 / 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.43,
  );

  /// 17pt Regular. The default reading size.
  static const TextStyle body = TextStyle(
    fontSize: 17,
    height: 22 / 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.43,
  );

  /// 16pt Regular.
  static const TextStyle callout = TextStyle(
    fontSize: 16,
    height: 21 / 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.32,
  );

  /// 15pt Regular. The secondary line of a list row.
  static const TextStyle subheadline = TextStyle(
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  /// 13pt Regular. Explanatory text under a group.
  static const TextStyle footnote = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.03,
  );

  /// 12pt Regular. Timestamps and axis labels.
  static const TextStyle caption1 = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.12,
  );

  /// 11pt Regular. The smallest supported size.
  static const TextStyle caption2 = TextStyle(
    fontSize: 11,
    height: 13 / 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
  );

  /// A group header in a grouped list: 13pt, uppercase, wide tracking, secondary colour.
  static const TextStyle groupHeader = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
  );

  /// The large numeral in a metric tile.
  ///
  /// [FontFeature.tabularFigures] is the important part: with proportional digits every character
  /// has its own width, so a value updating once a second visibly jitters as digits change. Tabular
  /// figures give every digit the same advance width, and the number stays put.
  static const TextStyle metricValue = TextStyle(
    fontSize: 40,
    height: 1.05,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.6,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// A smaller metric readout, same tabular treatment.
  static const TextStyle metricValueSmall = TextStyle(
    fontSize: 22,
    height: 1.1,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// The unit following a metric value, set smaller and lighter so the number dominates.
  static const TextStyle metricUnit = TextStyle(
    fontSize: 17,
    height: 1.2,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
  );

  /// Monospaced digits at body size, for tables and elapsed time.
  static const TextStyle monoBody = TextStyle(
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
