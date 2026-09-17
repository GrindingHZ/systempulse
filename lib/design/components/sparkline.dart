import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';

/// A compact line chart drawn directly onto the canvas.
///
/// Custom-painted rather than delegating to a charting package. A chart library brings a default
/// visual language — axis furniture, grid lines, tooltips, legends — that has to be fought back at
/// every step to reach a restrained result, and it pins the app to a third-party release cadence.
/// The drawing here is a few dozen lines and gives exact control over curvature, the gradient
/// under the line, and how gaps in the data are represented.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.minimum = 0,
    this.maximum = 100,
    this.strokeWidth = 2,
    this.fill = true,
  });

  /// Oldest first. Nulls are gaps — intervals where the device reported nothing — and the line is
  /// broken across them rather than interpolated, so missing data never looks like measured data.
  final List<double?> values;

  final Color color;
  final double minimum;
  final double maximum;
  final double strokeWidth;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          color: color,
          minimum: minimum,
          maximum: maximum,
          strokeWidth: strokeWidth,
          fill: fill,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.color,
    required this.minimum,
    required this.maximum,
    required this.strokeWidth,
    required this.fill,
  });

  final List<double?> values;
  final Color color;
  final double minimum;
  final double maximum;
  final double strokeWidth;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;

    final range = maximum - minimum;
    if (range <= 0) return;

    // Inset by half the stroke so the line is not clipped at the extremes of the range.
    final top = strokeWidth / 2;
    final usableHeight = math.max(0.0, size.height - strokeWidth);
    final stepX = size.width / (values.length - 1);

    Offset pointAt(int index, double value) {
      final normalised = ((value - minimum) / range).clamp(0.0, 1.0);
      return Offset(index * stepX, top + usableHeight * (1 - normalised));
    }

    // Each run of consecutive non-null values becomes its own path, so a gap in the data is a gap
    // in the line.
    final runs = <List<Offset>>[];
    var current = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) {
        if (current.length > 1) runs.add(current);
        current = <Offset>[];
        continue;
      }
      current.add(pointAt(i, value));
    }
    if (current.length > 1) runs.add(current);
    if (runs.isEmpty) return;

    final strokePaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true;

    for (final run in runs) {
      final path = _smoothPath(run);

      if (fill) {
        final fillPath =
            Path.from(path)
              ..lineTo(run.last.dx, size.height)
              ..lineTo(run.first.dx, size.height)
              ..close();

        canvas.drawPath(
          fillPath,
          Paint()
            ..shader = ui.Gradient.linear(Offset(0, top), Offset(0, size.height), [
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0.0),
            ]),
        );
      }

      canvas.drawPath(path, strokePaint);
    }
  }

  /// Builds a path through [points] using Catmull-Rom style control points.
  ///
  /// Straight segments between samples produce visible corners at every data point, which reads as
  /// noisy at this density. Control points placed at the midpoints of adjacent samples give a
  /// continuous curve that still passes exactly through every measured value — important for a
  /// chart of real data, where a spline that overshoots would draw peaks that were never recorded.
  Path _smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 2) {
      path.lineTo(points[1].dx, points[1].dy);
      return path;
    }

    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final point = points[i];
      final midpoint = Offset((previous.dx + point.dx) / 2, (previous.dy + point.dy) / 2);
      path.quadraticBezierTo(previous.dx, previous.dy, midpoint.dx, midpoint.dy);
    }

    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.color != color ||
      old.minimum != minimum ||
      old.maximum != maximum ||
      old.strokeWidth != strokeWidth ||
      old.fill != fill ||
      !_sameValues(old.values, values);

  static bool _sameValues(List<double?> a, List<double?> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
