# SystemPulse - Simple Integration (Compatible with Dart SDK 3.7.2)

## Option 1: Super Simple - Manual Copy Integration

Since you're getting SDK compatibility issues, here's the easiest approach:

### 1. Copy Files Directly to Your App

Instead of using the package, copy these files directly to your other Flutter app:

**Copy these 4 files to your app's `lib/` folder:**

1. **lib/performance_data.dart** (from system_pulse_package/lib/src/performance_data.dart)
2. **lib/performance_provider.dart** (from system_pulse_package/lib/src/performance_provider.dart) 
3. **lib/floating_overlay_provider.dart** (from system_pulse_package/lib/src/floating_overlay_provider.dart)
4. **lib/system_pulse_wrapper.dart** (from system_pulse_package/lib/src/system_pulse_wrapper.dart)

### 2. Add Dependencies to Your App

Add to your app's `pubspec.yaml`:
```yaml
dependencies:
  provider: ^6.1.1
```

### 3. Copy Android Code

**Copy these files to your app's Android folder:**

From `cpu_memory_tracking_app/android/app/src/main/kotlin/com/example/cpu_memory_tracking_app/`:
- Copy the performance methods from `MainActivity.kt` 
- Copy `OverlayService.kt`

**Add to your app's `android/app/src/main/AndroidManifest.xml`:**
```xml
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
```

### 4. Integrate in Your App

```dart
// main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'system_pulse_wrapper.dart';  // Your copied file

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SystemPulseWrapper(
        child: YourExistingHomePage(),
      ),
    );
  }
}
```

## Option 2: Package Integration (If SDK Issue Resolved)

Add to your app's `pubspec.yaml`:
```yaml
dependencies:
  system_pulse_monitor:
    path: ../path/to/system_pulse_package
```

Then wrap your app:
```dart
SystemPulseWrapper(
  child: YourApp(),
)
```

## What You Get

- Small floating button in top-right corner
- Tap to start/stop performance overlay
- Overlay shows CPU and memory usage
- Works across all apps when overlay is active

## Troubleshooting SDK 3.7.2 Issues

If you're still getting SDK compatibility errors:

1. **Use Option 1 (Manual Copy)** - This avoids all package dependency issues
2. **Check provider version** - Try `provider: ^6.0.0` instead of `^6.1.1`
3. **Update your constraints** - Make sure your app's `pubspec.yaml` has compatible versions

The manual copy approach (Option 1) is often the most reliable for SDK compatibility issues.
