import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import 'design/palette.dart';
import 'design/typography.dart';
import 'features/dashboard_screen.dart';
import 'features/device_screen.dart';
import 'features/history_screen.dart';
import 'features/settings_screen.dart';
import 'state/monitor_controller.dart';

/// Root of the application.
///
/// Built on [CupertinoApp] rather than `MaterialApp`. That choice carries more than a widget
/// library: it brings iOS scroll physics, the sliding back gesture, large collapsing titles,
/// translucent navigation chrome and native-feeling page transitions, all of which are load-bearing
/// for the intended feel and none of which are reproducible by restyling Material components.
class SystemPulseApp extends StatelessWidget {
  const SystemPulseApp({super.key, required this.controller});

  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MonitorController>.value(
      value: controller,
      child: Consumer<MonitorController>(
        builder: (context, controller, _) {
          return CupertinoApp(
            title: 'SystemPulse',
            debugShowCheckedModeBanner: false,
            theme: CupertinoThemeData(
              // Null follows the platform, which is what most people expect and what the settings
              // screen presents as "Automatic".
              brightness: controller.themeOverride,
              primaryColor: Palette.accent,
              scaffoldBackgroundColor: Palette.canvas,
              // Applying the type scale at the theme level means a plain Text anywhere in the app
              // already has the right size, weight, leading and tracking.
              textTheme: CupertinoTextThemeData(
                primaryColor: Palette.accent,
                textStyle: AppText.body.copyWith(color: Palette.label),
                navTitleTextStyle: AppText.headline.copyWith(color: Palette.label),
                navLargeTitleTextStyle: AppText.largeTitle.copyWith(color: Palette.label),
                tabLabelTextStyle: AppText.caption2,
                actionTextStyle: AppText.body.copyWith(color: Palette.accent),
              ),
            ),
            home: const _RootTabs(),
          );
        },
      ),
    );
  }
}

class _RootTabs extends StatelessWidget {
  const _RootTabs();

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.waveform_path_ecg), label: 'Monitor'),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.square_stack_3d_up),
            label: 'Recordings',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.device_phone_portrait),
            label: 'Device',
          ),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.gear), label: 'Settings'),
        ],
      ),
      tabBuilder: (context, index) {
        // Each tab gets its own navigator, so a push inside one tab does not disturb the others and
        // the back gesture stays scoped where the user expects.
        return CupertinoTabView(
          builder:
              (context) => CupertinoPageScaffold(
                backgroundColor: Palette.of(context, Palette.canvas),
                child: switch (index) {
                  0 => const DashboardScreen(),
                  1 => const HistoryScreen(),
                  2 => const DeviceScreen(),
                  _ => const SettingsScreen(),
                },
              ),
        );
      },
    );
  }
}
