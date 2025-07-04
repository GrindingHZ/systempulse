import 'package:flutter/material.dart';
import 'package:cpu_memory_tracking_app/widgets/device_info_widget.dart';

class DeviceInfoScreen extends StatelessWidget {
  const DeviceInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Information'),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: DeviceInfoWidget(),
      ),
    );
  }
}
