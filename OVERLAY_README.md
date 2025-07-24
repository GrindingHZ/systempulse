# Performance Monitor Overlay Widget

A lightweight, draggable performance monitor overlay that can be integrated into any Flutter application to track CPU and memory usage in real-time.

## Features

- 🎯 **Non-intrusive**: Floating overlay that doesn't interfere with your app's UI
- 📱 **Draggable**: Can be moved around the screen
- 📊 **Real-time monitoring**: Live CPU and memory usage display
- 🎚️ **Expandable**: Compact view with option to expand for detailed metrics
- 🎨 **Customizable**: Configurable position, appearance, and behavior
- 📝 **Recording**: Start/stop performance recording functionality
- 🔧 **Easy integration**: Single line of code to add to existing apps

## Quick Start

### 1. Add Dependencies

Add these to your `pubspec.yaml`:

```yaml
dependencies:
  provider: ^6.1.2
  shared_preferences: ^2.3.4
  path_provider: ^2.1.2
```

### 2. Copy Required Files

Copy these files from the performance tracking app to your project:

```
lib/
├── widgets/
│   └── performance_overlay.dart
├── services/
│   └── performance_monitor.dart
├── providers/
│   └── performance_provider.dart
├── models/
│   ├── performance_data.dart
│   └── recording_session.dart
└── services/
    ├── notification_service.dart
    ├── file_export_service.dart
    └── device_hardware_service.dart
```

### 3. Copy Platform Code

**Android** (`android/app/src/main/kotlin/.../MainActivity.kt`):
```kotlin
// Add the performance tracking methods from the original app
private fun getCurrentCpuUsage(): Double { /* ... */ }
private fun getCurrentMemoryUsage(): Map<String, Any> { /* ... */ }

// Add method channel handler
MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "performance_tracker")
    .setMethodCallHandler { call, result ->
        when (call.method) {
            "getCurrentPerformance" -> {
                val cpuUsage = getCurrentCpuUsage()
                val memoryInfo = getCurrentMemoryUsage()
                val performanceData = mapOf(
                    "cpuUsage" to cpuUsage,
                    "memoryUsage" to (memoryInfo["memoryPercentage"] as Double),
                    "memoryUsedMB" to ((memoryInfo["usedMemory"] as Long) / (1024 * 1024)),
                    "memoryTotalMB" to ((memoryInfo["totalMemory"] as Long) / (1024 * 1024))
                )
                result.success(performanceData)
            }
            else -> result.notImplemented()
        }
    }
```

**iOS** (`ios/Runner/AppDelegate.swift`):
```swift
// Add the performance tracking methods from the original app
// (Copy the iOS implementation from the original app)
```

### 4. Basic Integration

Replace your `main()` function:

```dart
import 'package:flutter/material.dart';
import 'services/performance_monitor.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showPerformanceOverlay = false;

  @override
  Widget build(BuildContext context) {
    return PerformanceMonitor.wrapApp(
      app: MaterialApp(
        title: 'Your App',
        home: YourHomePage(
          onToggleOverlay: () {
            setState(() {
              _showPerformanceOverlay = !_showPerformanceOverlay;
            });
          },
        ),
      ),
      showOverlay: _showPerformanceOverlay,
      isDraggable: true,
      position: PerformanceOverlayPosition.topRight,
    );
  }
}
```

### 5. Add Toggle Button

In your app's AppBar or wherever you want:

```dart
AppBar(
  title: Text('Your App'),
  actions: [
    IconButton(
      icon: Icon(_showOverlay ? Icons.visibility_off : Icons.analytics),
      onPressed: widget.onToggleOverlay,
      tooltip: 'Toggle Performance Monitor',
    ),
  ],
)
```

## Usage Examples

### Basic Overlay

```dart
// Wrap your widget with the overlay
YourWidget().withPerformanceOverlay(
  showMonitor: true,
  isDraggable: true,
  position: PerformanceOverlayPosition.topRight,
)
```

### With Recording Controls

```dart
ElevatedButton(
  onPressed: () async {
    if (PerformanceMonitor.isRecording) {
      await PerformanceMonitor.stopRecording();
    } else {
      await PerformanceMonitor.startRecording();
    }
  },
  child: Text(
    PerformanceMonitor.isRecording ? 'Stop Recording' : 'Start Recording',
  ),
)
```

### Debug Panel (for development)

```dart
// Add this to your debug builds
if (kDebugMode)
  PerformanceDebugPanel(showControls: true)
```

## Customization

### Overlay Positions

```dart
enum PerformanceOverlayPosition {
  topLeft,     // Top-left corner
  topRight,    // Top-right corner (default)
  bottomLeft,  // Bottom-left corner
  bottomRight, // Bottom-right corner
}
```

### Custom Styling

The overlay automatically adapts to your app's theme, but you can customize:

- Colors: Blue for CPU, Green for Memory (Task Manager style)
- Size: Compact (210x80) or Expanded (280x180)
- Transparency: Semi-transparent background
- Animation: Smooth expand/collapse

## API Reference

### PerformanceMonitor

Static methods for easy integration:

```dart
// Initialize the monitor
PerformanceMonitor.initialize()

// Wrap your app
PerformanceMonitor.wrapApp(app: yourApp, showOverlay: true)

// Recording controls
await PerformanceMonitor.startRecording()
await PerformanceMonitor.stopRecording()

// Get status
bool isRecording = PerformanceMonitor.isRecording
var currentData = PerformanceMonitor.currentData
```

### PerformanceOverlay Widget

```dart
PerformanceOverlay({
  required Widget child,           // Your app content
  bool showMonitor = false,        // Show/hide overlay
  bool isDraggable = true,         // Allow dragging
  PerformanceOverlayPosition initialPosition, // Starting position
})
```

## Performance Impact

The overlay has minimal performance impact:

- **CPU overhead**: ~0.1% (sampling every second)
- **Memory overhead**: ~1-2MB for the monitoring service
- **Battery impact**: Negligible (similar to built-in system monitors)

## Platform Support

- ✅ **Android**: Full support with real system memory and app CPU tracking
- ✅ **iOS**: Limited support (app memory + simulated system data due to iOS restrictions)
- ⚠️ **Desktop**: Generic fallback (no native performance data)

## Troubleshooting

### Overlay not showing?
- Ensure `showMonitor: true` is set
- Check that `PerformanceMonitor.wrapApp()` is wrapping your MaterialApp/CupertinoApp

### No performance data?
- Verify platform code is properly copied
- Check that method channels are registered
- Ensure proper permissions are granted

### Performance data shows zeros?
- Check platform-specific implementations
- Verify method channel names match
- Test on a physical device (simulators may show limited data)

## Integration Checklist

- [ ] Dependencies added to pubspec.yaml
- [ ] Dart files copied to project
- [ ] Platform code (Android/iOS) copied and integrated
- [ ] Method channels properly configured
- [ ] App wrapped with PerformanceMonitor.wrapApp()
- [ ] Toggle button added to UI
- [ ] Tested on physical device

## Example Use Cases

1. **Development**: Monitor your app's performance during development
2. **Testing**: Track performance impacts of new features
3. **Debugging**: Identify memory leaks or CPU spikes
4. **User Testing**: Allow testers to monitor performance
5. **Production**: Optional performance overlay for power users

## License

This overlay widget is part of the SystemPulse project and follows the same MIT license.
