import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'performance_provider.dart';
import 'floating_overlay_provider.dart';

/// Minimal wrapper that adds performance monitoring to any Flutter app
class SystemPulseWrapper extends StatelessWidget {
  final Widget child;

  const SystemPulseWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PerformanceProvider>(
          create: (context) => PerformanceProvider(),
        ),
        ChangeNotifierProxyProvider<PerformanceProvider, FloatingOverlayProvider>(
          create: (context) => FloatingOverlayProvider(),
          update: (context, performanceProvider, floatingOverlayProvider) {
            floatingOverlayProvider!.setPerformanceProvider(performanceProvider);
            return floatingOverlayProvider;
          },
        ),
      ],
      child: child, // Just return the child without Stack to avoid Directionality issues
    );
  }
}

/// Use this widget inside your app (after MaterialApp) to show the floating button
class SystemPulseFloatingButton extends StatelessWidget {
  const SystemPulseFloatingButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 50,
      right: 10,
      child: Consumer<FloatingOverlayProvider>(
        builder: (context, provider, child) {
          return FloatingActionButton.small(
            onPressed: () async {
              await provider.toggleOverlay();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      provider.isOverlayActive 
                        ? 'Floating overlay started! Switch to other apps to see monitoring.'
                        : 'Floating overlay stopped.',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Icon(
              provider.isOverlayActive 
                ? Icons.picture_in_picture 
                : Icons.analytics,
            ),
          );
        },
      ),
    );
  }
}
