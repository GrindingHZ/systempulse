# SystemPulse Integration for greensheart_app (Dart 3.7.2)

## ✅ Fixed Compatibility Issue

I've updated the SystemPulse package to be compatible with Dart SDK 3.7.2.

## Integration Options

### Option 1: Git Dependency (Now Works!)

Add to your `greensheart_app/pubspec.yaml`:

```yaml
dependencies:
  system_pulse_monitor:
    git:
      url: https://github.com/GrindingHZ/systemfulse.git
      path: system_pulse_package
```

### Option 2: Local Path (If cloned locally)

```yaml
dependencies:
  system_pulse_monitor:
    path: ../cpu_memory_tracking_app/system_pulse_package
```

## Quick Integration

**1. Add dependency and run:**
```bash
fvm flutter pub get
```

**2. Wrap your app in `main.dart`:**
```dart
import 'package:flutter/material.dart';
import 'package:system_pulse_monitor/system_pulse_monitor.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SystemPulseWrapper(
        child: YourExistingGreensheartHomePage(),
      ),
    );
  }
}
```

**3. Add Android permission to `android/app/src/main/AndroidManifest.xml`:**
```xml
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
```

## What You'll Get

- 📊 Small floating button in top-right corner of your app
- 📱 Tap to start floating performance overlay
- 🔄 Overlay shows CPU and memory usage of your greensheart_app
- 🌐 Monitor your app performance while using other apps
- 🎯 Zero configuration needed!

## How to Use

1. Run your greensheart_app: `fvm flutter run`
2. Look for analytics button (📊) in top-right corner
3. Tap to start floating overlay
4. Grant overlay permission if prompted
5. Switch to other apps - the overlay follows showing your app's performance!

The floating overlay will show real-time CPU and memory usage of your greensheart_app, perfect for monitoring how it performs while you use other applications.

## Updated Compatibility

- ✅ Dart SDK: `>=3.7.0 <4.0.0` (compatible with 3.7.2)
- ✅ Provider: `^6.0.0` (stable version)
- ✅ Flutter: `>=3.7.0`

Try running `fvm flutter pub get` in your greensheart_app now - the version conflict should be resolved!
