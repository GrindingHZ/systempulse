import 'package:flutter/cupertino.dart';

import '../palette.dart';
import '../tokens.dart';
import '../typography.dart';
import 'sparkline.dart';
import 'surface.dart';

/// A single live metric: label, current value, and its recent history.
///
/// The value is the largest element on the tile and everything else defers to it — the label sits
/// above in secondary colour at footnote size, the unit trails the number in a lighter weight, and
/// the sparkline is a low-contrast band at the bottom. That ordering is the whole design: one
/// thing to read at a glance, context available if wanted.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.history = const [],
    this.minimum = 0,
    this.maximum = 100,
    this.caption,
    this.onTap,
  });

  final String label;

  /// Null renders as an em dash: the device did not report a reading. Never shown as zero, which
  /// would be indistinguishable from a real measurement of zero.
  final double? value;

  final String unit;
  final Color color;
  final List<double?> history;
  final double minimum;
  final double maximum;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = Palette.of(context, color);
    final hasValue = value != null;

    // The surface carries no padding of its own so the sparkline can run the full width of the
    // card while the text stays inset. The text block supplies its own padding instead.
    return Surface(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: resolvedColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.footnote.copyWith(
                          color: Palette.of(context, Palette.labelSecondary),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                // Baseline-aligned so the unit sits on the number's baseline rather than floating
                // against the cap height, which is how a unit is set alongside a numeral.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: _AnimatedValue(
                        value: value,
                        style: AppText.metricValue.copyWith(
                          color: Palette.of(context, Palette.label),
                        ),
                      ),
                    ),
                    if (hasValue) ...[
                      const SizedBox(width: 2),
                      Text(
                        unit,
                        style: AppText.metricUnit.copyWith(
                          color: Palette.of(context, Palette.labelTertiary),
                        ),
                      ),
                    ],
                  ],
                ),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption1.copyWith(
                      color: Palette.of(context, Palette.labelTertiary),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Spacing.sm),
          SizedBox(
            height: 34,
            width: double.infinity,
            child: Sparkline(
              values: history,
              color: resolvedColor,
              minimum: minimum,
              maximum: maximum,
            ),
          ),
          // Keeps the stroke clear of the card's rounded corners. Without it the line runs into
          // the curve and the gradient is sliced by the clip, which reads as a rendering fault
          // rather than as a deliberate edge.
          const SizedBox(height: Spacing.md),
        ],
      ),
    );
  }
}

/// Renders a metric value, easing between readings.
///
/// A number replaced outright once a second flickers and is hard to read. Interpolating over most
/// of the sampling interval turns each update into a short count, which the eye tracks comfortably.
/// The tween is short enough that the displayed figure is never meaningfully behind the data.
class _AnimatedValue extends StatelessWidget {
  const _AnimatedValue({required this.value, required this.style});

  final double? value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return Text('—', style: style.copyWith(color: Palette.of(context, Palette.labelQuaternary)));
    }

    return TweenAnimationBuilder<double>(
      // Only `end` may change between builds. TweenAnimationBuilder animates from whatever is
      // currently displayed to the new end, so `begin` is used once, for the initial count-up.
      tween: Tween<double>(begin: 0, end: value),
      duration: Motion.medium,
      curve: Motion.standard,
      builder:
          (context, animated, _) =>
              Text(animated.toStringAsFixed(animated >= 100 ? 0 : 1), maxLines: 1, style: style),
    );
  }
}
