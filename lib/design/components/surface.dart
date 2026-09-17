import 'package:flutter/cupertino.dart';

import '../palette.dart';
import '../tokens.dart';

/// A raised container in the style of an iOS grouped-list section.
///
/// The corner is drawn as a superellipse rather than a circular arc. This is the shape Apple uses
/// throughout iOS and the difference is visible at these radii: a circular corner changes curvature
/// abruptly where it meets the straight edge, which reads as a subtle crease, while a superellipse
/// transitions continuously. Flutter renders the real thing via [ClipRSuperellipse].
///
/// The shadow is deliberately almost invisible — a very soft, low-opacity fill that separates the
/// surface from the canvas without announcing itself. Apple's surfaces are distinguished by
/// *colour* against a grouped background first, with shadow as a faint reinforcement; the previous
/// design's `elevation: 4` drop shadows are the single clearest tell of a non-native interface.
class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.lg),
    this.radius = Radii.medium,
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;

  /// When set, the surface presses inward on touch, matching how iOS cells respond.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final resolved = Palette.of(context, color ?? Palette.surface);
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    final surface = ClipRSuperellipse(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(color: resolved, child: Padding(padding: padding, child: child)),
    );

    final shadowed = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow:
            isDark
                // In dark mode the surface is lighter than the canvas, so a shadow would be invisible
                // at best and muddy at worst. Contrast alone carries the separation.
                ? const []
                : [
                  BoxShadow(
                    color: const Color(0xFF000000).withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
      ),
      child: surface,
    );

    if (onTap == null) return shadowed;
    return _PressableSurface(onTap: onTap!, child: shadowed);
  }
}

/// Scales its child down slightly while pressed.
///
/// iOS gives a tappable cell immediate physical feedback. The scale is small (0.98) and the spring
/// settles quickly, so it registers as responsiveness rather than as an animation.
class _PressableSurface extends StatefulWidget {
  const _PressableSurface({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PressableSurface> createState() => _PressableSurfaceState();
}

class _PressableSurfaceState extends State<_PressableSurface> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.fast,
    reverseDuration: Motion.medium,
  );

  late final Animation<double> _scale = Tween<double>(begin: 1, end: 0.98).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOut, reverseCurve: Curves.easeOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// A one-physical-pixel rule, inset from the leading edge the way iOS insets row separators.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = Spacing.separatorInset});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent),
      child: SizedBox(
        height: Hairlines.width(context),
        child: ColoredBox(color: Palette.of(context, Palette.separator)),
      ),
    );
  }
}

/// The uppercase caption above a grouped section.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.xl, Spacing.lg, Spacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(title.toUpperCase(), style: AppTextStyles.groupHeaderResolved(context)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Small helpers that bind a text style to the resolved colour for the current theme.
abstract final class AppTextStyles {
  static TextStyle groupHeaderResolved(BuildContext context) => TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    color: Palette.of(context, Palette.labelSecondary),
  );
}
