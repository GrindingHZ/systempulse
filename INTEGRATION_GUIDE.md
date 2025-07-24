# SystemPulse Integration Guide

## Overview
To monitor CPU and memory usage of another Flutter app, you need to integrate SystemPulse monitoring capabilities directly into that target app.

## Integration Options

### Option 1: Package Integration (Recommended)
Convert SystemPulse into a Flutter package that can be added as a dependency to any Flutter app.

### Option 2: Direct Code Integration
Copy the monitoring components directly into the target app.

### Option 3: Flutter Plugin
Create a Flutter plugin that other apps can use.

## What Gets Integrated

### Core Monitoring Components:
1. **PerformanceProvider** - Core monitoring logic
2. **FloatingOverlayProvider** - Overlay management
3. **Native Android Code** - CPU/Memory collection methods
4. **Floating Overlay Service** - System overlay functionality

### Files to Extract:
- `lib/providers/performance_provider.dart`
- `lib/providers/floating_overlay_provider.dart`
- `lib/services/floating_overlay_service.dart`
- `lib/models/performance_data.dart`
- `lib/models/hardware_info.dart`
- `android/app/src/main/kotlin/.../MainActivity.kt` (performance methods)
- `android/app/src/main/kotlin/.../OverlayService.kt`

## Integration Steps

### Step 1: Create Flutter Package Structure
```
system_pulse_monitor/
├── lib/
│   ├── system_pulse_monitor.dart
│   ├── src/
│   │   ├── providers/
│   │   ├── services/
│   │   ├── models/
│   │   └── widgets/
├── android/
│   └── src/main/kotlin/
└── pubspec.yaml
```

### Step 2: Extract Core Functionality
Move the performance monitoring logic into the package structure.

### Step 3: Add to Target App
In the target app's `pubspec.yaml`:
```yaml
dependencies:
  system_pulse_monitor:
    path: ../system_pulse_monitor  # or git/pub.dev reference
```

### Step 4: Initialize in Target App
```dart
// In target app's main.dart
import 'package:system_pulse_monitor/system_pulse_monitor.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Other providers...
        ChangeNotifierProvider(create: (_) => PerformanceProvider()),
        ChangeNotifierProvider(create: (_) => FloatingOverlayProvider()),
      ],
      child: MaterialApp(
        home: SystemPulseWrapper(
          child: YourOriginalHomePage(),
        ),
      ),
    );
  }
}
```

## Benefits of This Approach

1. **Accurate Monitoring**: Gets actual CPU usage of the target app
2. **Real-time Data**: Monitors the app while it's actually running
3. **System-wide Memory**: Still provides system memory information
4. **Minimal Integration**: Easy to add to existing Flutter apps
5. **Reusable**: Can be used across multiple Flutter projects

## Limitations

- Only works with Flutter apps (not native Android/iOS apps)
- Requires code modification of the target app
- Still shows process-specific CPU usage, not system-wide

## Alternative: True System-wide Monitoring

For monitoring ANY app (not just Flutter), you would need:
1. Root access or system-level permissions
2. Access to `/proc/stat` and `/proc/[pid]/stat`
3. Background service with elevated permissions
4. Much more complex implementation

Would you like me to create the package structure for easy integration into other Flutter apps?
