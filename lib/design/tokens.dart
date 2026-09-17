import 'package:flutter/cupertino.dart';

/// Layout, shape and motion constants.
///
/// Apple's interfaces are built on a small number of repeated values rather than one-off numbers,
/// which is most of why they read as a single system. Everything spatial here is a multiple of 4,
/// and screens use these constants instead of literals.
abstract final class Spacing {
  /// Hairline gaps: between a label and the value directly beneath it.
  static const double xs = 4;

  /// Within a component: icon to label, or stacked lines of related text.
  static const double sm = 8;

  /// Between rows in a list.
  static const double md = 12;

  /// The standard iOS screen margin, and the default padding inside a grouped row.
  static const double lg = 16;

  /// Between a group and the next group's header.
  static const double xl = 24;

  /// Between major sections of a screen.
  static const double xxl = 32;

  /// Horizontal margin from the screen edge to content.
  static const double screenMargin = 16;

  /// Where a separator starts, so it aligns with the text above it rather than the screen edge.
  /// iOS insets separators to the leading text origin; a full-bleed rule reads as a divider
  /// between sections instead of between rows.
  static const double separatorInset = 16;
}

/// Corner radii.
///
/// iOS corners are superellipses ("squircles"), not circular arcs: curvature is continuous where
/// the corner meets the edge, so there is no visible break. Flutter models this exactly with
/// [BorderRadius] applied through an `RSuperellipse` shape, which [Surface] uses.
abstract final class Radii {
  /// Small controls: pills, badges, compact buttons.
  static const double small = 10;

  /// The standard grouped-list container radius on iOS.
  static const double medium = 14;

  /// Emphasised cards and sheets.
  static const double large = 20;

  /// Modal sheet top corners.
  static const double sheet = 28;
}

/// Motion.
///
/// Apple animates with springs rather than fixed-duration eased curves: a spring carries the
/// velocity of the gesture that started it, so motion feels continuous with the user's input
/// instead of replayed. Durations here are for the few cases where a spring is inappropriate,
/// such as a cross-fade.
abstract final class Motion {
  /// A state change the user caused directly and is watching for.
  static const Duration fast = Duration(milliseconds: 180);

  /// The default for a visible transition.
  static const Duration medium = Duration(milliseconds: 280);

  /// Deliberately slow, for something entering from off-screen.
  static const Duration slow = Duration(milliseconds: 420);

  /// Matches the spring iOS uses for sliding segmented controls: settles quickly with a trace of
  /// overshoot, which reads as responsive rather than bouncy.
  static const SpringDescription spring = SpringDescription(
    mass: 1,
    stiffness: 503.551,
    damping: 44.8799,
  );

  /// A gentler spring for elements that move a longer distance.
  static const SpringDescription gentleSpring = SpringDescription(
    mass: 1,
    stiffness: 280,
    damping: 32,
  );

  /// Curve for non-spring transitions. [Curves.easeOutCubic] closely matches the deceleration of
  /// iOS's own cross-fades and avoids the mechanical feel of a linear curve.
  static const Curve standard = Curves.easeOutCubic;

  /// For something leaving the screen, where the user's attention has already moved on.
  static const Curve exit = Curves.easeInCubic;
}

/// Hairline rules.
abstract final class Hairlines {
  /// iOS separators are one physical pixel, not one logical point. On a 3x screen that is 0.33pt.
  /// Drawing them at 1.0pt makes an interface look coarse at exactly the scale where Apple's looks
  /// crisp.
  static double width(BuildContext context) => 1 / MediaQuery.devicePixelRatioOf(context);
}
