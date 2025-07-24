import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/performance_provider.dart';
import '../widgets/performance_overlay.dart';

/// A simple class to help integrate performance monitoring into any Flutter app
class PerformanceMonitor {
  static bool _isInitialized = false;
  static PerformanceProvider? _provider;
  
  /// Initialize the performance monitor
  static void initialize() {
    if (!_isInitialized) {
      _provider = PerformanceProvider();
      _isInitialized = true;
    }
  }
  
  /// Wrap your MaterialApp or CupertinoApp with this method
  static Widget wrapApp({
    required Widget app,
    bool showOverlay = false,
    bool isDraggable = true,
    PerformanceOverlayPosition position = PerformanceOverlayPosition.topRight,
  }) {
    initialize();
    
    return ChangeNotifierProvider<PerformanceProvider>.value(
      value: _provider!,
      child: app.withPerformanceOverlay(
        showMonitor: showOverlay,
        isDraggable: isDraggable,
        position: position,
      ),
    );
  }
  
  /// Get the current performance provider
  static PerformanceProvider? get provider => _provider;
  
  /// Start recording performance data
  static Future<void> startRecording() async {
    await _provider?.startRecording();
  }
  
  /// Stop recording performance data
  static Future<void> stopRecording() async {
    await _provider?.stopRecording();
  }
  
  /// Check if currently recording
  static bool get isRecording => _provider?.isRecording ?? false;
  
  /// Get current performance data
  static get currentData => _provider?.currentData;
  
  /// Dispose resources
  static void dispose() {
    _provider?.dispose();
    _provider = null;
    _isInitialized = false;
  }
}

/// A toggleable floating action button for the performance overlay
class PerformanceToggleFAB extends StatefulWidget {
  final Widget? child;
  final Color? backgroundColor;
  final Color? foregroundColor;
  
  const PerformanceToggleFAB({
    Key? key,
    this.child,
    this.backgroundColor,
    this.foregroundColor,
  }) : super(key: key);

  @override
  State<PerformanceToggleFAB> createState() => _PerformanceToggleFABState();
}

class _PerformanceToggleFABState extends State<PerformanceToggleFAB> {
  bool _showOverlay = false;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: widget.backgroundColor ?? Colors.blue,
      foregroundColor: widget.foregroundColor ?? Colors.white,
      onPressed: () {
        setState(() {
          _showOverlay = !_showOverlay;
        });
        
        // Update the overlay visibility in the app
        _updateOverlayVisibility();
      },
      child: widget.child ?? Icon(
        _showOverlay ? Icons.visibility_off : Icons.analytics,
      ),
    );
  }
  
  void _updateOverlayVisibility() {
    // This is a simplified approach - in a real implementation,
    // you might want to use a state management solution
    // to communicate with the overlay widget
  }
}

/// A debug panel widget that can be used during development
class PerformanceDebugPanel extends StatelessWidget {
  final bool showControls;
  
  const PerformanceDebugPanel({
    Key? key,
    this.showControls = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PerformanceProvider>(
      builder: (context, provider, child) {
        final currentData = provider.currentData;
        
        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Performance Monitor',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              if (currentData != null) ...[
                _buildMetricRow('CPU Usage', '${currentData.cpuUsage.toStringAsFixed(1)}%'),
                _buildMetricRow('Memory Usage', '${currentData.memoryUsage.toStringAsFixed(1)}%'),
                _buildMetricRow('Memory Used', '${(currentData.memoryUsedMB / 1024).toStringAsFixed(2)} GB'),
                _buildMetricRow('Memory Total', '${(currentData.memoryTotalMB / 1024).toStringAsFixed(2)} GB'),
                _buildMetricRow('Recording', provider.isRecording ? 'Active' : 'Inactive'),
              ] else ...[
                const Text(
                  'No performance data available',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
              
              if (showControls) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: provider.isRecording 
                          ? () => provider.stopRecording()
                          : () => provider.startRecording(),
                      child: Text(provider.isRecording ? 'Stop Recording' : 'Start Recording'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        // Export functionality can be added here
                      },
                      child: const Text('Export'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
