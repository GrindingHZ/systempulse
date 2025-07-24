import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/performance_provider.dart';

/// A simple performance overlay that shows CPU and Memory usage
/// This version avoids directionality issues by using simple positioning
class SimplePerformanceOverlay extends StatefulWidget {
  final Widget child;
  final bool showMonitor;

  const SimplePerformanceOverlay({
    Key? key,
    required this.child,
    this.showMonitor = false,
  }) : super(key: key);

  @override
  State<SimplePerformanceOverlay> createState() => _SimplePerformanceOverlayState();
}

class _SimplePerformanceOverlayState extends State<SimplePerformanceOverlay> {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          if (widget.showMonitor)
            Positioned(
              top: 50,
              right: 10,
              child: _buildOverlayContent(),
            ),
        ],
      ),
    );
  }

  Widget _buildOverlayContent() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 200,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.blue.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Consumer<PerformanceProvider>(
          builder: (context, provider, child) {
            final currentData = provider.currentData;
            
            if (currentData == null) {
              return const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Text(
                    'Performance',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // CPU and Memory indicators
                  Row(
                    children: [
                      _buildMetricIndicator(
                        'CPU',
                        currentData.cpuUsage,
                        Colors.blue,
                      ),
                      const SizedBox(width: 16),
                      _buildMetricIndicator(
                        'MEM',
                        currentData.memoryUsage,
                        Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMetricIndicator(String label, double value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                '${value.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: LinearProgressIndicator(
                  value: value / 100,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
