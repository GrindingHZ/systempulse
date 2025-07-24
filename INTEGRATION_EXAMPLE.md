# Integration Example

## Scenario: Adding SystemPulse to an existing Flutter app

Let's say you have another Flutter app called "MyShoppingApp" and you want to monitor its performance.

### Step 1: Add SystemPulse Package

In `my_shopping_app/pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  # Your existing dependencies...
  system_pulse_monitor:
    path: ../cpu_memory_tracking_app/system_pulse_package
```

### Step 2: Modify main.dart

**Before:**
```dart
void main() {
  runApp(MyShoppingApp());
}

class MyShoppingApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shopping App',
      home: HomePage(),
    );
  }
}
```

**After:**
```dart
import 'package:system_pulse_monitor/system_pulse_monitor.dart';

void main() {
  runApp(MyShoppingApp());
}

class MyShoppingApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shopping App',
      home: SystemPulseWrapper(
        enableFloatingOverlay: true,
        child: HomePage(),
      ),
    );
  }
}
```

### Step 3: Test the Integration

1. Run your shopping app
2. You'll see a small floating overlay button
3. Tap it to start the floating overlay
4. Minimize the shopping app
5. The overlay will show real-time CPU/Memory usage of your shopping app

### Step 4: Monitor Different Scenarios

Now you can monitor your shopping app's performance during:

- **Product browsing**: See CPU usage when scrolling through products
- **Image loading**: Monitor memory usage when loading product images
- **Cart operations**: Check performance during add/remove items
- **Checkout process**: Monitor during payment processing
- **Background state**: See resource usage when app is minimized

### What You'll See

#### CPU Usage
- Low usage (0.1-2%) during idle states
- Higher usage (5-15%) during scrolling/animations
- Spikes during heavy operations (image processing, data loading)

#### Memory Usage
- System-wide memory consumption
- Your app's specific memory footprint
- Memory patterns during different app states

## Real-world Benefits

### For Developers:
1. **Performance Optimization**: Identify bottlenecks in real-time
2. **Memory Leak Detection**: Monitor memory usage patterns
3. **Battery Impact**: Understand CPU consumption impact
4. **User Experience**: Ensure smooth performance across features

### For QA Testing:
1. **Performance Regression**: Catch performance issues in builds
2. **Device Testing**: Compare performance across different devices
3. **Stress Testing**: Monitor during heavy usage scenarios
4. **Background Behavior**: Verify efficient background operation

### For Production Monitoring:
1. **Real-world Performance**: Monitor actual user scenarios
2. **Issue Diagnosis**: Understand performance in production
3. **Resource Planning**: Understand app resource requirements
4. **Optimization Validation**: Verify that optimizations work

## Advanced Integration

### Custom Performance Alerts

```dart
class ShoppingAppWithMonitoring extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SystemPulseWrapper(
      child: Consumer<PerformanceProvider>(
        builder: (context, performance, child) {
          // Alert if CPU usage is too high
          if (performance.currentData?.cpuUsage > 20.0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text('High CPU Usage'),
                  content: Text('App is using ${performance.currentData?.cpuUsage.toStringAsFixed(1)}% CPU'),
                ),
              );
            });
          }
          
          return HomePage();
        },
      ),
    );
  }
}
```

### Performance Logging

```dart
class PerformanceLogger extends StatefulWidget {
  final Widget child;
  
  @override
  Widget build(BuildContext context) {
    return Consumer<PerformanceProvider>(
      builder: (context, performance, child) {
        // Log performance data
        final data = performance.currentData;
        if (data != null) {
          print('Performance: CPU=${data.cpuUsage}%, Memory=${data.memoryUsage}%');
          
          // Send to analytics
          FirebaseAnalytics.instance.logEvent(
            name: 'performance_data',
            parameters: {
              'cpu_usage': data.cpuUsage,
              'memory_usage': data.memoryUsage,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            },
          );
        }
        
        return child;
      },
    );
  }
}
```

This approach gives you **true monitoring of your target Flutter app's performance** rather than just monitoring the SystemPulse app itself.
