import 'package:flutter/material.dart';
import 'services/performance_monitor.dart';
import 'widgets/performance_overlay.dart';

/// Example showing how to integrate the performance monitor overlay
/// into any existing Flutter application
class ExampleAppWithPerformanceOverlay extends StatefulWidget {
  const ExampleAppWithPerformanceOverlay({Key? key}) : super(key: key);

  @override
  State<ExampleAppWithPerformanceOverlay> createState() => _ExampleAppWithPerformanceOverlayState();
}

class _ExampleAppWithPerformanceOverlayState extends State<ExampleAppWithPerformanceOverlay> {
  bool _showPerformanceOverlay = false;

  @override
  Widget build(BuildContext context) {
    // Method 1: Using the PerformanceMonitor helper class (Recommended)
    return PerformanceMonitor.wrapApp(
      app: MaterialApp(
        title: 'Your App with Performance Monitor',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: _buildMainScreen(),
      ),
      showOverlay: _showPerformanceOverlay,
      isDraggable: true,
      position: PerformanceOverlayPosition.topRight,
    );
  }

  Widget _buildMainScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your App'),
        actions: [
          // Toggle button for performance overlay
          IconButton(
            icon: Icon(
              _showPerformanceOverlay ? Icons.visibility_off : Icons.analytics,
            ),
            onPressed: () {
              setState(() {
                _showPerformanceOverlay = !_showPerformanceOverlay;
              });
            },
            tooltip: 'Toggle Performance Monitor',
          ),
        ],
      ),
      body: _buildAppContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Your app's main action
          _simulateWork();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAppContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your App Content',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          const Text(
            'This is your existing app content. The performance monitor overlay '
            'can be toggled on/off using the button in the app bar.',
          ),
          
          const SizedBox(height: 24),
          
          // Example of triggering performance monitoring
          ElevatedButton(
            onPressed: () async {
              if (PerformanceMonitor.isRecording) {
                await PerformanceMonitor.stopRecording();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Performance recording stopped')),
                );
              } else {
                await PerformanceMonitor.startRecording();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Performance recording started')),
                );
              }
            },
            child: Text(
              PerformanceMonitor.isRecording 
                  ? 'Stop Recording Performance' 
                  : 'Start Recording Performance',
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Simulate some work to see CPU usage
          ElevatedButton(
            onPressed: _simulateWork,
            child: const Text('Simulate CPU Work'),
          ),
          
          const SizedBox(height: 24),
          
          // Example of using the debug panel (for development)
          if (_showPerformanceOverlay)
            const PerformanceDebugPanel(showControls: true),
          
          // Your existing app widgets go here...
          ...List.generate(20, (index) => Card(
            child: ListTile(
              title: Text('Item $index'),
              subtitle: Text('This is item number $index'),
              leading: CircleAvatar(child: Text('$index')),
            ),
          )),
        ],
      ),
    );
  }

  void _simulateWork() {
    // Simulate some CPU-intensive work to see the performance monitor in action
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsedMilliseconds < 1000) {
      // Busy wait for 1 second to simulate CPU work
      for (int i = 0; i < 1000000; i++) {
        // Some calculations
        final result = i * i + i;
        if (result < 0) break; // This will never happen, just to use the variable
      }
    }
    stopwatch.stop();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Simulated work for ${stopwatch.elapsedMilliseconds}ms')),
    );
  }
}

/// Alternative implementation - Manual integration without helper class
class ManualIntegrationExample extends StatefulWidget {
  const ManualIntegrationExample({Key? key}) : super(key: key);

  @override
  State<ManualIntegrationExample> createState() => _ManualIntegrationExampleState();
}

class _ManualIntegrationExampleState extends State<ManualIntegrationExample> {
  bool _showOverlay = false;

  @override
  Widget build(BuildContext context) {
    // Method 2: Manual integration using the extension method
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Manual Integration Example'),
          actions: [
            IconButton(
              icon: Icon(_showOverlay ? Icons.visibility_off : Icons.visibility),
              onPressed: () {
                setState(() {
                  _showOverlay = !_showOverlay;
                });
              },
            ),
          ],
        ),
        body: const Center(
          child: Text('Your app content here'),
        ),
      ).withPerformanceOverlay(
        showMonitor: _showOverlay,
        isDraggable: true,
        position: PerformanceOverlayPosition.topLeft,
      ),
    );
  }
}

/// Usage instructions and examples
class UsageInstructions {
  /// To integrate into your existing app, follow these steps:
  /// 
  /// 1. Copy the necessary files to your project:
  ///    - lib/widgets/performance_overlay.dart
  ///    - lib/services/performance_monitor.dart
  ///    - lib/providers/performance_provider.dart
  ///    - lib/models/performance_data.dart
  ///    - lib/models/recording_session.dart
  ///    - Native platform code (Android: MainActivity.kt, iOS: AppDelegate.swift)
  /// 
  /// 2. Add dependencies to your pubspec.yaml:
  ///    - provider: ^6.1.2
  ///    - shared_preferences: ^2.3.4
  ///    - path_provider: ^2.1.2
  /// 
  /// 3. Replace your main() function:
  /// ```dart
  /// void main() {
  ///   runApp(PerformanceMonitor.wrapApp(
  ///     app: MyApp(),
  ///     showOverlay: false, // Set to true to show overlay by default
  ///   ));
  /// }
  /// ```
  /// 
  /// 4. Add a toggle button in your app:
  /// ```dart
  /// IconButton(
  ///   icon: Icon(showOverlay ? Icons.visibility_off : Icons.analytics),
  ///   onPressed: () {
  ///     setState(() {
  ///       showOverlay = !showOverlay;
  ///     });
  ///   },
  /// )
  /// ```
  /// 
  /// 5. Optional: Add recording controls:
  /// ```dart
  /// ElevatedButton(
  ///   onPressed: () async {
  ///     if (PerformanceMonitor.isRecording) {
  ///       await PerformanceMonitor.stopRecording();
  ///     } else {
  ///       await PerformanceMonitor.startRecording();
  ///     }
  ///   },
  ///   child: Text(PerformanceMonitor.isRecording ? 'Stop' : 'Start'),
  /// )
  /// ```
}
