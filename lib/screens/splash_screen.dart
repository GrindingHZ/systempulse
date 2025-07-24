import 'package:flutter/material.dart';
import 'package:cpu_memory_tracking_app/screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback? onToggleOverlay;
  final bool? showOverlay;
  
  const SplashScreen({
    super.key,
    this.onToggleOverlay,
    this.showOverlay,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  void _initializeApp() async {
    // App initialization time
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            onToggleOverlay: widget.onToggleOverlay,
            showOverlay: widget.showOverlay ?? false,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo with name
            Image.asset(
              'assets/final_logo_with_name.png',
              width: 350,
              height: 220,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 40),
            // Simple loading indicator
            const CircularProgressIndicator(
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
