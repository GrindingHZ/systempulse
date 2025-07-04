import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cpu_memory_tracking_app/providers/performance_provider.dart';

class AnimatedGridOverlay extends StatelessWidget {
  final double height;
  final Color gridColor;

  const AnimatedGridOverlay({
    super.key,
    required this.height,
    required this.gridColor,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PerformanceProvider>(
      builder: (context, provider, child) {
        return CustomPaint(
          size: Size(double.infinity, height),
          painter: AnimatedGridPainter(
            chartDurationSeconds: provider.chartDurationSeconds,
            gridColor: gridColor,
            currentTime: DateTime.now(),
          ),
        );
      },
    );
  }
}

class AnimatedGridPainter extends CustomPainter {
  final int chartDurationSeconds;
  final Color gridColor;
  final DateTime currentTime;

  AnimatedGridPainter({
    required this.chartDurationSeconds,
    required this.gridColor,
    required this.currentTime,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor.withValues(alpha: 0.3) // Set transparency to 0.3
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Calculate grid spacing (12 vertical lines like Task Manager)
    final gridSpacing = size.width / 12.0;
    
    // Calculate the scrolling offset based on current time
    // This creates the effect of grid lines moving left as time progresses
    final secondsElapsed = currentTime.millisecondsSinceEpoch / 1000.0;
    final pixelsPerSecond = size.width / chartDurationSeconds;
    final scrollOffset = (secondsElapsed * pixelsPerSecond) % gridSpacing;

    // Draw vertical grid lines that scroll with time (dotted)
    for (int i = -1; i <= 13; i++) { // Draw extra lines for smooth scrolling
      final x = (i * gridSpacing) - scrollOffset;
      if (x >= -2 && x <= size.width + 2) { // Only draw lines that might be visible
        _drawDottedLine(
          canvas,
          Offset(x, 0),
          Offset(x, size.height),
          paint,
        );
      }
    }

    // Draw horizontal grid lines (static, dotted, like Task Manager)
    for (int i = 0; i <= 4; i++) { // 0%, 25%, 50%, 75%, 100%
      final y = (i * size.height / 4);
      _drawDottedLine(
        canvas,
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  void _drawDottedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const double dashWidth = 3;
    const double dashSpace = 3;
    
    final double distance = (end - start).distance;
    final Offset direction = (end - start) / distance;
    
    double currentDistance = 0;
    bool isDash = true;
    
    while (currentDistance < distance) {
      final double segmentLength = isDash ? dashWidth : dashSpace;
      final double remainingDistance = distance - currentDistance;
      final double actualLength = segmentLength > remainingDistance ? remainingDistance : segmentLength;
      
      if (isDash) {
        final Offset segmentStart = start + direction * currentDistance;
        final Offset segmentEnd = start + direction * (currentDistance + actualLength);
        canvas.drawLine(segmentStart, segmentEnd, paint);
      }
      
      currentDistance += actualLength;
      isDash = !isDash;
    }
  }

  @override
  bool shouldRepaint(AnimatedGridPainter oldDelegate) {
    // Repaint when time changes (every second) to create animation
    return oldDelegate.currentTime != currentTime ||
           oldDelegate.chartDurationSeconds != chartDurationSeconds ||
           oldDelegate.gridColor != gridColor;
  }
}
