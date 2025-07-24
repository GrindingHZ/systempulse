# SystemPulse Integration for Greensheart App - COMPLETE GUIDE

## 🔧 **STEP 1: Fix Your pubspec.yaml**

Replace your current `pubspec.yaml` with this corrected version:

**Key Changes:**
- ✅ Fixed SDK version: `">=3.7.0 <4.0.0"` (compatible with SystemPulse)
- ✅ Corrected Git URL: `systemfulse.git` (not `systempulse`)
- ✅ Correct package: `system_pulse_monitor` (not `cpu_memory_tracking_app`)
- ✅ Correct path: `system_pulse_package`

```yaml
name: greensheart_app
description: A new Flutter project.
publish_to: "none"

version: 1.7.1+1

environment:
  sdk: ">=3.7.0 <4.0.0"  # ← FIXED: Compatible with SystemPulse

dependencies:
  # SystemPulse Integration - CORRECTED
  system_pulse_monitor:
    git:
      url: https://github.com/GrindingHZ/systemfulse.git  # ← FIXED: Correct URL
      path: system_pulse_package  # ← FIXED: Correct path
      
  flutter:
    sdk: flutter

  # ... rest of your existing dependencies stay the same ...
  cupertino_icons: ^1.0.2
  fluro: ^2.0.5
  mobx: ^2.2.0
  # (keep all your other dependencies as they are)
```

## 🚀 **STEP 2: Update Your main.dart**

**FIXED: Correct way to integrate SystemPulse:**

```dart
import 'package:flutter/material.dart';
import 'package:system_pulse_monitor/system_pulse_monitor.dart';  // ← ADD THIS

// Wrap at the TOP LEVEL (around the entire app)
void main() {
  runApp(
    SystemPulseWrapper(  // ← Wrap here, not around MaterialApp
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Your existing code stays exactly the same
    return Observer(builder: (context) {
      return MaterialApp(
        locale: AppInfoStore().locale,
        builder: getBuilder(context),
        debugShowCheckedModeBanner: false,
        initialRoute: getInitialRoute(),
        title: 'GreenSHeart',
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: L10n.all,
        theme: AppTheme.appTheme,
        onGenerateRoute: Routes.router.generator,
      );
    });
  }
}
```

**OR Alternative: Add floating button to a specific screen:**

If you want more control, add the floating button to a specific screen:

```dart
import 'package:system_pulse_monitor/system_pulse_monitor.dart';

class YourMainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          YourExistingScreenContent(),
          SystemPulseFloatingButton(), // ← Add floating button to any screen
        ],
      ),
    );
  }
}
```

## 📱 **STEP 3: Add Android Permission**

Add to your `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Add this permission for floating overlay -->
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
    
    <!-- ... rest of your existing manifest ... -->
</manifest>
```

## ⚡ **STEP 4: Clean & Rebuild (CRITICAL)**

**IMPORTANT:** After adding the SystemPulse dependency, you MUST clean and rebuild to register the Android plugin:

```bash
# 1. Clean everything
fvm flutter clean

# 2. Get dependencies 
fvm flutter pub get

# 3. Clean Android build (very important!)
cd android
./gradlew clean
cd ..

# 4. Run the app
fvm flutter run
```

**Why this is needed:** The SystemPulse package includes Android native code that needs to be compiled and registered with your app. Flutter needs a clean build to properly integrate the plugin.

## 🎯 **What You'll Get**

1. **📊 Floating Button**: Small analytics button in top-right corner of your app
2. **🔄 Tap to Monitor**: Tap button to start floating performance overlay
3. **📱 Cross-App Monitoring**: Overlay shows CPU/Memory usage of your greensheart_app while you use other apps
4. **⚡ Real-time Data**: Updates every second

## 💡 **How to Use**

1. **Run greensheart_app**: `fvm flutter run`
2. **Look for button**: Small analytics icon (📊) in top-right corner
3. **Start monitoring**: Tap the button
4. **Grant permission**: Allow overlay permission if prompted
5. **Switch apps**: The overlay follows you and shows greensheart_app performance!

## 🛠️ **Optional: Access Performance Data in Your Code**

If you want to display performance data inside your greensheart_app:

```dart
import 'package:provider/provider.dart';
import 'package:system_pulse_monitor/system_pulse_monitor.dart';

// In any widget:
Consumer<PerformanceProvider>(
  builder: (context, performance, child) {
    final data = performance.currentData;
    return Text('CPU: ${data?.cpuUsage.toStringAsFixed(1)}%');
  },
)
```

## ✅ **Summary of Fixes**

| Problem | Solution |
|---------|----------|
| Wrong package name | `cpu_memory_tracking_app` → `system_pulse_monitor` |
| Wrong Git URL | `systempulse` → `systemfulse` |
| Wrong path | Missing `path: system_pulse_package` |
| SDK compatibility | `>=3.0.1` → `>=3.7.0 <4.0.0` |

Use the corrected `pubspec.yaml` I provided above, and your SystemPulse integration should work perfectly! 🎉
