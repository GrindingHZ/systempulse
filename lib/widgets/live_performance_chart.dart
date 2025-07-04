import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:cpu_memory_tracking_app/providers/performance_provider.dart';
import 'package:cpu_memory_tracking_app/models/performance_data.dart';
import 'package:cpu_memory_tracking_app/widgets/animated_grid_overlay.dart';

class LivePerformanceChart extends StatelessWidget {
  final double height;
  final bool showCpu;
  final bool showMemory;

  const LivePerformanceChart({
    super.key,
    this.height = 200,
    this.showCpu = true,
    this.showMemory = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Theme-aware colors
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5);
    final borderColor = Colors.black; // Always black border like Task Manager
    final textColor = isDark ? Colors.white70 : Colors.black54;
    final gridColor = isDark ? const Color(0xFFBBBBBB) : const Color(0xFF999999); // Whitish in dark mode, darker in light mode
    
    // Correct Task Manager colors (CPU = blue, Memory = green)
    final cpuColor = isDark ? const Color(0xFF00AAFF) : const Color(0xFF0078D4); // CPU is BLUE
    final memoryColor = isDark ? const Color(0xFF00D084) : const Color(0xFF00AA44); // Memory is GREEN
    
    return Consumer<PerformanceProvider>(
      builder: (context, provider, child) {
        final chartData = provider.liveChartData;
        
        if (chartData.isEmpty) {
          return Container(
            height: height,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Center(
              child: Text(
                'Loading performance data...',
                style: TextStyle(color: textColor),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top labels row above the chart
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side - % Utilization
                  Text(
                    '% Utilization',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  // Right side - 100%
                  Text(
                    '100%',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4), // Small gap between labels and chart
            // Chart container
            Container(
              height: height,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7), // Slightly smaller to fit inside border
                child: Stack(
                  children: [
                    // Background chart without grid lines (no spawning animation)
                    LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false), // Disable static grid, use animated overlay instead
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false), // Remove fl_chart's border since we have our own
                        minX: 0, // Start exactly at 0
                        maxX: provider.chartDurationSeconds.toDouble(), // End exactly at chart duration
                        minY: 0, // Start exactly at 0%
                        maxY: 100, // End exactly at 100%
                        clipData: FlClipData.all(), // Clip to chart bounds
                        extraLinesData: ExtraLinesData(), // Remove any extra lines
                        lineTouchData: LineTouchData(enabled: false), // Disable touch to remove padding
                        lineBarsData: _buildLineChartBarData(chartData, provider.chartDurationSeconds, cpuColor, memoryColor, isDark),
                      ),
                      duration: Duration.zero, // Disable implicit animations for chart lines
                      curve: Curves.linear, // Use linear curve to avoid easing effects
                    ),
                    // Animated grid overlay (moves with data)
                    AnimatedGridOverlay(
                      height: height - 2, // Account for border
                      gridColor: gridColor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4), // Small gap between chart and bottom labels
            // Bottom labels row below the chart
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side - Chart duration
                  Text(
                    '${provider.chartDurationSeconds}s',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  // Right side - 0
                  Text(
                    '0',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<LineChartBarData> _buildLineChartBarData(
    List<PerformanceData> data, 
    int chartDurationSeconds, 
    Color cpuColor, 
    Color memoryColor, 
    bool isDark,
  ) {
    final now = DateTime.now();
    final List<LineChartBarData> result = [];

    // CPU line (blue like Task Manager)
    if (showCpu) {
      final cpuSpots = <FlSpot>[];
      
      // Add data points
      for (final point in data) {
        final secondsAgo = now.difference(point.timestamp).inSeconds;
        final x = (chartDurationSeconds - secondsAgo).toDouble();
        if (x >= 0 && x <= chartDurationSeconds) { // Only include visible area
          cpuSpots.add(FlSpot(x, point.cpuUsage));
        }
      }
      
      // Ensure line extends to edges by adding boundary points
      if (cpuSpots.isNotEmpty) {
        // Sort spots by x coordinate
        cpuSpots.sort((a, b) => a.x.compareTo(b.x));
        
        // Add point at left edge (x=0) if not already there
        if (cpuSpots.first.x > 0) {
          cpuSpots.insert(0, FlSpot(0, cpuSpots.first.y));
        }
        // Add point at right edge (x=chartDuration) if not already there
        if (cpuSpots.last.x < chartDurationSeconds.toDouble()) {
          cpuSpots.add(FlSpot(chartDurationSeconds.toDouble(), cpuSpots.last.y));
        }
        
        result.add(
          LineChartBarData(
            spots: cpuSpots,
            isCurved: false, // Straight lines for natural shifting effect
            color: cpuColor, // Theme-aware CPU color
            barWidth: 2, // Thinner lines
            isStrokeCapRound: false, // Sharp edges for more natural look
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: cpuColor.withValues(alpha: isDark ? 0.25 : 0.20), // Reduced transparency for better visibility
            ),
          ),
        );
      }
    }

    // Memory line (green like Task Manager)
    if (showMemory) {
      final memorySpots = <FlSpot>[];
      
      // Add data points
      for (final point in data) {
        final secondsAgo = now.difference(point.timestamp).inSeconds;
        final x = (chartDurationSeconds - secondsAgo).toDouble();
        if (x >= 0 && x <= chartDurationSeconds) { // Only include visible area
          memorySpots.add(FlSpot(x, point.memoryUsage));
        }
      }
      
      // Ensure line extends to edges by adding boundary points
      if (memorySpots.isNotEmpty) {
        // Sort spots by x coordinate
        memorySpots.sort((a, b) => a.x.compareTo(b.x));
        
        // Add point at left edge (x=0) if not already there
        if (memorySpots.first.x > 0) {
          memorySpots.insert(0, FlSpot(0, memorySpots.first.y));
        }
        // Add point at right edge (x=chartDuration) if not already there
        if (memorySpots.last.x < chartDurationSeconds.toDouble()) {
          memorySpots.add(FlSpot(chartDurationSeconds.toDouble(), memorySpots.last.y));
        }
        
        result.add(
          LineChartBarData(
            spots: memorySpots,
            isCurved: false, // Straight lines for natural shifting effect
            color: memoryColor, // Theme-aware Memory color
            barWidth: 2, // Thinner lines
            isStrokeCapRound: false, // Sharp edges for more natural look
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: memoryColor.withValues(alpha: isDark ? 0.25 : 0.20), // Reduced transparency for better visibility
            ),
          ),
        );
      }
    }

    return result;
  }
}
