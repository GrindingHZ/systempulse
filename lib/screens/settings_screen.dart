import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cpu_memory_tracking_app/providers/theme_provider.dart';
import 'package:cpu_memory_tracking_app/providers/performance_provider.dart';
import 'package:cpu_memory_tracking_app/utils/theme.dart';
import 'package:cpu_memory_tracking_app/services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    _notificationsEnabled = await _notificationService.isNotificationEnabled();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(context, 'Appearance'),
          _buildThemeSelector(context),
          const SizedBox(height: 24),
          
          _buildSectionHeader(context, 'Notifications'),
          _buildNotificationSettings(context),
          const SizedBox(height: 24),
          
          _buildSectionHeader(context, 'Performance'),
          _buildPerformanceSettings(context),
          const SizedBox(height: 24),
          
          _buildSectionHeader(context, 'About'),
          _buildAboutSection(context),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppTheme.primaryBlue,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(LucideIcons.sun),
                title: const Text('Light'),
                trailing: Radio<ThemeMode>(
                  value: ThemeMode.light,
                  groupValue: themeProvider.themeMode,
                  onChanged: (value) => themeProvider.setThemeMode(value!),
                ),
                onTap: () => themeProvider.setThemeMode(ThemeMode.light),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(LucideIcons.moon),
                title: const Text('Dark'),
                trailing: Radio<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: themeProvider.themeMode,
                  onChanged: (value) => themeProvider.setThemeMode(value!),
                ),
                onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(LucideIcons.monitor),
                title: const Text('System'),
                trailing: Radio<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: themeProvider.themeMode,
                  onChanged: (value) => themeProvider.setThemeMode(value!),
                ),
                onTap: () => themeProvider.setThemeMode(ThemeMode.system),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationSettings(BuildContext context) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(LucideIcons.bell),
            title: const Text('Recording Notifications'),
            subtitle: const Text('Show notifications during recording sessions'),
            value: _notificationsEnabled,
            onChanged: (value) async {
              if (value) {
                await _notificationService.requestNotificationPermissions();
              }
              setState(() {
                _notificationsEnabled = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceSettings(BuildContext context) {
    return Consumer<PerformanceProvider>(
      builder: (context, performanceProvider, child) {
        return Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(LucideIcons.settings),
                title: const Text('Sampling Interval'),
                subtitle: Text(performanceProvider.getSamplingIntervalText()),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => _showSamplingIntervalDialog(context, performanceProvider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(LucideIcons.info),
            title: const Text('About SystemPulse'),
            subtitle: const Text('Version 1.0.0'),
            onTap: () => _showAboutDialog(context),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(LucideIcons.fileText),
            title: const Text('Privacy Policy'),
            trailing: const Icon(LucideIcons.externalLink),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy policy coming soon')),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(LucideIcons.users),
            title: const Text('Open Source Licenses'),
            trailing: const Icon(LucideIcons.externalLink),
            onTap: () => showLicensePage(context: context),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'SystemPulse',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2025 SystemPulse. All rights reserved.',
      children: [
        const SizedBox(height: 16),
        const Text(
          'SystemPulse is a powerful system performance monitoring app built with Flutter. '
          'Monitor your device\'s CPU and memory usage in real-time, record performance sessions, '
          'and export data for analysis.',
        ),
      ],
    );
  }

  void _showSamplingIntervalDialog(BuildContext context, PerformanceProvider performanceProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        int selectedInterval = performanceProvider.recordingInterval;
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              icon: const Icon(LucideIcons.settings, color: AppTheme.primaryBlue),
              title: const Text('Sampling Interval'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Choose how often performance data is recorded during sessions:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  RadioListTile<int>(
                    title: const Text('1 second'),
                    subtitle: const Text('High precision, larger files'),
                    value: 1,
                    groupValue: selectedInterval,
                    onChanged: (value) {
                      setState(() {
                        selectedInterval = value!;
                      });
                    },
                  ),
                  RadioListTile<int>(
                    title: const Text('10 seconds'),
                    subtitle: const Text('Balanced precision and file size'),
                    value: 10,
                    groupValue: selectedInterval,
                    onChanged: (value) {
                      setState(() {
                        selectedInterval = value!;
                      });
                    },
                  ),
                  RadioListTile<int>(
                    title: const Text('1 minute'),
                    subtitle: const Text('Lower precision, smaller files'),
                    value: 60,
                    groupValue: selectedInterval,
                    onChanged: (value) {
                      setState(() {
                        selectedInterval = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    await performanceProvider.setSamplingInterval(selectedInterval);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Sampling interval set to ${performanceProvider.getSamplingIntervalText()}',
                          ),
                          backgroundColor: AppTheme.successGreen,
                        ),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}