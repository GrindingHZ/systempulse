import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:cpu_memory_tracking_app/providers/performance_provider.dart';
import 'package:cpu_memory_tracking_app/providers/floating_overlay_provider.dart';
import 'package:cpu_memory_tracking_app/utils/theme.dart';
import 'package:cpu_memory_tracking_app/widgets/animated_gauge.dart';
import 'package:cpu_memory_tracking_app/widgets/live_performance_chart.dart';
import 'package:cpu_memory_tracking_app/widgets/recording_indicator.dart';
import 'package:cpu_memory_tracking_app/widgets/device_info_widget.dart';
import 'package:cpu_memory_tracking_app/screens/recording_history_screen.dart';
import 'package:cpu_memory_tracking_app/screens/settings_screen.dart';
import 'package:cpu_memory_tracking_app/screens/device_info_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onToggleOverlay;
  final bool showOverlay;
  
  const HomeScreen({
    super.key,
    this.onToggleOverlay,
    this.showOverlay = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _DashboardView(
            onToggleOverlay: widget.onToggleOverlay,
            showOverlay: widget.showOverlay,
          ),
          const RecordingHistoryScreen(),
          const DeviceInfoScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.activity),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.smartphone),
            label: 'Device',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _DashboardView extends StatelessWidget {
  final VoidCallback? onToggleOverlay;
  final bool showOverlay;
  
  const _DashboardView({
    this.onToggleOverlay,
    this.showOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/final_logo.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('SystemPulse'),
          ],
        ),
        actions: [
          Consumer<PerformanceProvider>(
            builder: (context, provider, child) {
              return RecordingIndicator(
                isRecording: provider.isRecording,
                duration: provider.currentRecordingDuration,
              );
            },
          ),
          // Performance Overlay Toggle Button
          if (onToggleOverlay != null)
            IconButton(
              icon: Icon(
                showOverlay ? Icons.visibility_off : Icons.analytics,
                color: showOverlay ? Colors.green : null,
              ),
              onPressed: onToggleOverlay,
              tooltip: showOverlay ? 'Hide Performance Overlay' : 'Show Performance Overlay',
            ),
          // Floating Overlay Toggle Button
          Consumer<FloatingOverlayProvider>(
            builder: (context, overlayProvider, child) {
              return IconButton(
                icon: Icon(
                  overlayProvider.isOverlayActive ? Icons.picture_in_picture : Icons.open_in_new,
                  color: overlayProvider.isOverlayActive ? Colors.orange : null,
                ),
                onPressed: () async {
                  await overlayProvider.toggleOverlay();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          overlayProvider.isOverlayActive 
                            ? 'Floating overlay started! You can now minimize the app and use other apps while monitoring performance.'
                            : 'Floating overlay stopped.',
                        ),
                        duration: const Duration(seconds: 3),
                        backgroundColor: overlayProvider.isOverlayActive ? Colors.green : Colors.orange,
                      ),
                    );
                  }
                },
                tooltip: overlayProvider.isOverlayActive 
                  ? 'Stop Floating Overlay' 
                  : 'Start Floating Overlay',
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Consumer<PerformanceProvider>(
        builder: (context, provider, child) {
          final currentData = provider.currentData;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date/Time Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.calendar,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE, MMMM d').format(DateTime.now()),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              DateFormat('h:mm a').format(DateTime.now()),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Device Information Card
                GestureDetector(
                  onTap: () {
                    // Navigate to Device Info screen when tapped
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const DeviceInfoScreen(),
                      ),
                    );
                  },
                  child: const DeviceInfoWidget(),
                ),

                const SizedBox(height: 24),

                // Real-time Gauges
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: AnimatedGauge(
                              value: currentData?.cpuUsage ?? 0.0,
                              label: 'CPU',
                              color: AppTheme.primaryBlue,
                              size: 140,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: AnimatedGauge(
                              value: currentData?.memoryUsage ?? 0.0,
                              label: 'Memory',
                              color: AppTheme.accentTeal,
                              size: 140,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Live Chart
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              LucideIcons.trendingUp,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Live Performance',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Legend
                        Row(
                          children: [
                            _buildLegendItem('CPU', AppTheme.primaryBlue),
                            const SizedBox(width: 24),
                            _buildLegendItem('Memory', AppTheme.accentTeal),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const LivePerformanceChart(),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // CPU Details Card
                Consumer<PerformanceProvider>(
                  builder: (context, provider, child) {
                    final hardwareInfo = provider.hardwareInfo;
                    if (hardwareInfo == null) {
                      return const SizedBox(); // Don't show card until hardware info is loaded
                    }
                    
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  LucideIcons.cpu,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Processor Information',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildCpuDetail(
                                  context,
                                  'Name',
                                  _truncateProcessorName(hardwareInfo.processorName),
                                  AppTheme.primaryBlue,
                                ),
                                _buildCpuDetail(
                                  context,
                                  'Cores',
                                  '${hardwareInfo.coreCount} core${hardwareInfo.coreCount == 1 ? '' : 's'}',
                                  AppTheme.accentTeal,
                                ),
                                _buildCpuDetail(
                                  context,
                                  'Architecture',
                                  hardwareInfo.architecture,
                                  AppTheme.successGreen,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Memory Details Card
                Consumer<PerformanceProvider>(
                  builder: (context, provider, child) {
                    final currentData = provider.currentData;
                    final hardwareInfo = provider.hardwareInfo;
                    
                    if (currentData == null) {
                      return const SizedBox();
                    }
                    
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  LucideIcons.memoryStick,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Memory Information',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Real-time memory usage
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildMemoryDetail(
                                  context,
                                  'Used',
                                  '${(currentData.memoryUsedMB / 1024).toStringAsFixed(1)} GB',
                                  AppTheme.accentTeal,
                                ),
                                _buildMemoryDetail(
                                  context,
                                  'Available',
                                  '${((currentData.memoryTotalMB - currentData.memoryUsedMB) / 1024).toStringAsFixed(1)} GB',
                                  AppTheme.successGreen,
                                ),
                                _buildMemoryDetail(
                                  context,
                                  'Total RAM',
                                  hardwareInfo?.totalRamGB ?? '${(currentData.memoryTotalMB / 1024).toStringAsFixed(1)} GB',
                                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 100), // Bottom padding for FAB
              ],
            ),
          );
        },
      ),
      floatingActionButton: Consumer<PerformanceProvider>(
        builder: (context, provider, child) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16, right: 16),
            child: ElevatedButton.icon(
              onPressed: () async {
                if (provider.isRecording) {
                  await _showStopRecordingDialog(context, provider);
                } else {
                  await provider.startRecording();
                }
              },
              icon: Icon(
                provider.isRecording ? LucideIcons.square : LucideIcons.play,
              ),
              label: Text(
                provider.isRecording ? 'Stop Recording' : 'Start Recording',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: provider.isRecording 
                    ? AppTheme.warningRed 
                    : AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMemoryDetail(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildCpuDetail(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Future<void> _showStopRecordingDialog(BuildContext context, PerformanceProvider provider) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(LucideIcons.square, color: AppTheme.warningRed),
          title: const Text('Stop Recording'),
          content: const Text('Are you sure you want to stop the recording? The data will be saved automatically.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.warningRed,
              ),
              child: const Text('Stop & Save'),
              onPressed: () async {
                Navigator.of(context).pop();
                await provider.stopRecording();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Recording saved successfully!'),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  String _truncateProcessorName(String name) {
    // Clean up and truncate processor name for dashboard display
    String cleaned = name
        .replaceAll('(R)', '®')
        .replaceAll('(TM)', '™')
        .replaceAll('(C)', '©')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    // Truncate if too long for dashboard
    if (cleaned.length > 20) {
      return '${cleaned.substring(0, 17)}...';
    }
    return cleaned;
  }
}
