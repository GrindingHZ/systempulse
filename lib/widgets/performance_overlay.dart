import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/performance_provider.dart';

class PerformanceOverlay extends StatefulWidget {
  final Widget child;
  final bool showMonitor;
  final bool isDraggable;
  final PerformanceOverlayPosition initialPosition;

  const PerformanceOverlay({
    Key? key,
    required this.child,
    this.showMonitor = false,
    this.isDraggable = true,
    this.initialPosition = PerformanceOverlayPosition.topRight,
  }) : super(key: key);

  @override
  State<PerformanceOverlay> createState() => _PerformanceOverlayState();
}

class _PerformanceOverlayState extends State<PerformanceOverlay> {
  Offset _position = const Offset(0, 50);
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _setInitialPosition();
  }

  void _setInitialPosition() {
    switch (widget.initialPosition) {
      case PerformanceOverlayPosition.topLeft:
        _position = const Offset(10, 50);
        break;
      case PerformanceOverlayPosition.topRight:
        _position = const Offset(-220, 50);
        break;
      case PerformanceOverlayPosition.bottomLeft:
        _position = const Offset(10, -150);
        break;
      case PerformanceOverlayPosition.bottomRight:
        _position = const Offset(-220, -150);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topLeft, // Use explicit alignment instead of directional
      textDirection: TextDirection.ltr, // Explicit text direction
      children: [
        widget.child,
        if (widget.showMonitor)
          Positioned(
            right: _position.dx < 0 ? -_position.dx : null,
            left: _position.dx >= 0 ? _position.dx : null,
            top: _position.dy >= 0 ? _position.dy : null,
            bottom: _position.dy < 0 ? -_position.dy : null,
            child: widget.isDraggable
                ? Draggable(
                    feedback: _buildOverlayContent(true),
                    childWhenDragging: Container(),
                    onDragStarted: () {
                      // Optional: Add visual feedback when dragging starts
                    },
                    onDragEnd: (details) {
                      setState(() {
                        _position = Offset(
                          details.offset.dx,
                          details.offset.dy,
                        );
                      });
                    },
                    child: _buildOverlayContent(false),
                  )
                : _buildOverlayContent(false),
          ),
      ],
    );
  }

  Widget _buildOverlayContent(bool isFeedback) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: _isExpanded ? 280 : 210,
        height: _isExpanded ? 180 : 80,
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
                  // Header with expand/collapse button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Performance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                        },
                        child: Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ),
                    ],
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
                  
                  if (_isExpanded) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white30, height: 1),
                    const SizedBox(height: 8),
                    
                    // Detailed information
                    _buildDetailRow(
                      'Memory Used',
                      '${(currentData.memoryUsedMB / 1024).toStringAsFixed(1)} GB',
                    ),
                    _buildDetailRow(
                      'Memory Total',
                      '${(currentData.memoryTotalMB / 1024).toStringAsFixed(1)} GB',
                    ),
                    _buildDetailRow(
                      'Recording',
                      provider.isRecording ? 'Active' : 'Inactive',
                      provider.isRecording ? Colors.red : Colors.grey,
                    ),
                  ],
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
                  fontSize: 14,
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

  Widget _buildDetailRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

enum PerformanceOverlayPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

// Extension to make it easy to wrap any widget
extension PerformanceMonitoring on Widget {
  Widget withPerformanceOverlay({
    bool showMonitor = false,
    bool isDraggable = true,
    PerformanceOverlayPosition position = PerformanceOverlayPosition.topRight,
  }) {
    return PerformanceOverlay(
      showMonitor: showMonitor,
      isDraggable: isDraggable,
      initialPosition: position,
      child: this,
    );
  }
}
