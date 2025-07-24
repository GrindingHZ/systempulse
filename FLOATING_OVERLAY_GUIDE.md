# SystemPulse - System-Wide Performance Monitoring

## 🎯 Overview
SystemPulse now includes a **system-wide floating overlay** that allows you to monitor the performance of ANY app on your device. The floating widget stays on top of all other applications, letting you track CPU and memory usage while using other apps.

## 🚀 How It Works

### 1. **System Overlay Technology**
- Uses Android's `SYSTEM_ALERT_WINDOW` permission
- Creates a native floating window that stays on top
- Updates performance data in real-time (every second)
- Works with any app on your device

### 2. **What It Monitors**
- **CPU Usage**: Real-time CPU consumption of the system
- **Memory Usage**: System memory usage percentage  
- **Live Updates**: Data refreshes every second automatically

### 3. **Two Monitoring Modes**

#### Mode 1: In-App Overlay (Current Implementation)
- Shows overlay within SystemPulse app only
- Disappears when you switch to other apps
- Good for testing and development

#### Mode 2: System-Wide Floating Widget (NEW!)
- Floats over ALL apps on your device
- Stays visible when using other apps
- Can monitor performance of any running application

## 📱 How to Use the Floating Overlay

### Step 1: Grant Permission
1. Open SystemPulse app
2. Tap the **floating window icon** (📱) in the top-right corner
3. Android will ask for "Display over other apps" permission
4. Grant the permission in system settings

### Step 2: Start Monitoring
1. Return to SystemPulse app
2. Tap the **floating window icon** again
3. A small floating widget will appear on screen
4. You'll see a success message

### Step 3: Use Other Apps
1. Press home button or switch to any other app
2. The floating widget stays visible over other apps
3. Watch real-time CPU and memory usage
4. Tap the widget to expand/collapse detailed view

### Step 4: Move and Interact
- **Drag**: Touch and drag to move the widget anywhere
- **Tap**: Single tap to expand/collapse details
- **Data**: Updates automatically every second

## 🔧 Widget Features

### Compact View (Default)
```
CPU 1.2%  MEM 85.4%
```

### Expanded View (Tap to Toggle)
```
CPU 1.2%  MEM 85.4%
CPU [████░░░░░░] 12%
MEM [████████░░] 85%
```

### Controls
- **Draggable**: Move anywhere on screen
- **Expandable**: Tap to show progress bars
- **Real-time**: Updates every second
- **Transparent**: Semi-transparent background

## 🎮 Use Cases

### 1. Gaming Performance
- Monitor CPU/Memory while playing games
- See which games use most resources
- Optimize gaming experience

### 2. App Development
- Test your app's performance impact
- Monitor resource usage during development
- Debug memory leaks and CPU spikes

### 3. System Monitoring
- Keep eye on overall system health
- Monitor background app impact
- Track resource usage patterns

### 4. Multitasking
- Monitor performance while working
- See impact of running multiple apps
- Optimize workflow efficiency

## ⚙️ Technical Details

### Platform Support
- **Android**: Full support with native overlay
- **iOS**: Limited (iOS restricts system overlays)
- **Desktop**: Not implemented (but possible)

### Permissions Required
- `SYSTEM_ALERT_WINDOW`: For floating overlay
- `ACTION_MANAGE_OVERLAY_PERMISSION`: For permission management

### Architecture
```
Flutter App (Dart)
    ↓
MethodChannel
    ↓
Android Native (Kotlin)
    ↓
OverlayService
    ↓
WindowManager (System Overlay)
```

### Data Flow
1. **PerformanceProvider** collects system data
2. **FloatingOverlayProvider** manages overlay state
3. **MethodChannel** sends data to Android
4. **OverlayService** updates native widget
5. **WindowManager** displays floating overlay

## 🔄 Integration Guide

### For Other Apps
To integrate this monitoring into your own Flutter app:

1. **Copy Required Files**:
   - `lib/services/floating_overlay_service.dart`
   - `lib/providers/floating_overlay_provider.dart`
   - `android/app/src/main/kotlin/.../OverlayService.kt`
   - `android/app/src/main/res/layout/floating_overlay.xml`

2. **Add Permissions**:
   ```xml
   <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
   ```

3. **Update MainActivity**:
   - Add floating overlay method channel
   - Include overlay service initialization

4. **Use in Your App**:
   ```dart
   // Start overlay
   await FloatingOverlayService.startOverlay();
   
   // Update with your app's performance data
   await FloatingOverlayService.updateOverlayData(
     cpuUsage: yourCpuData,
     memoryUsage: yourMemoryData,
   );
   ```

## 🐛 Troubleshooting

### Permission Issues
- **Problem**: Overlay permission denied
- **Solution**: Manually enable in Android Settings > Apps > SystemPulse > Display over other apps

### Widget Not Showing
- **Problem**: Widget doesn't appear
- **Solution**: Check if permission is granted, restart app if needed

### Performance Impact
- **Problem**: Overlay affects performance
- **Solution**: Widget is optimized to use minimal resources (updates only every second)

### Position Reset
- **Problem**: Widget position resets
- **Solution**: Position is saved automatically, drag to preferred location

## 🚀 Future Enhancements

### Planned Features
1. **Customizable Widget**: Choose what metrics to display
2. **Multiple Widgets**: Show different metrics in separate widgets
3. **App-Specific Monitoring**: Track specific app's performance
4. **Historical Data**: Show performance graphs in overlay
5. **Smart Positioning**: Auto-avoid important screen areas
6. **iOS Support**: When platform allows system overlays

### Advanced Monitoring
1. **Network Usage**: Monitor data consumption
2. **Battery Impact**: Track power usage
3. **GPU Usage**: Monitor graphics performance
4. **Temperature**: Device thermal monitoring

## 📖 Summary

The floating overlay feature transforms SystemPulse from an app-specific monitoring tool into a **system-wide performance monitor**. You can now:

✅ **Monitor any app's impact** on system resources  
✅ **Keep tracking while multitasking**  
✅ **See real-time performance data** floating over any app  
✅ **Drag and position** the widget anywhere you want  
✅ **Expand for detailed metrics** with progress bars  
✅ **Integrate into your own apps** easily  

This makes SystemPulse a powerful tool for developers, power users, and anyone who wants to understand their device's performance characteristics across all applications.
