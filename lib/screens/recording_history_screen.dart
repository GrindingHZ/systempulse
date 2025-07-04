import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:cpu_memory_tracking_app/providers/performance_provider.dart';
import 'package:cpu_memory_tracking_app/utils/theme.dart';
import 'package:cpu_memory_tracking_app/screens/recording_detail_screen.dart';

class RecordingHistoryScreen extends StatelessWidget {
  const RecordingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              LucideIcons.history,
              color: AppTheme.primaryBlue,
            ),
            const SizedBox(width: 8),
            const Text('Recording History'),
          ],
        ),
      ),
      body: Consumer<PerformanceProvider>(
        builder: (context, provider, child) {
          final sessions = provider.sessions;

          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.fileText,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No recordings yet',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start your first recording session from the dashboard',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[sessions.length - 1 - index]; // Reverse order
              return _RecordingSessionCard(session: session);
            },
          );
        },
      ),
    );
  }
}

class _RecordingSessionCard extends StatelessWidget {
  final dynamic session; // RecordingSession type

  const _RecordingSessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => RecordingDetailScreen(session: session),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with date and duration
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.calendar,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('MMM d, y').format(session.startTime),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatDuration(session.duration),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Time
              Row(
                children: [
                  Icon(
                    LucideIcons.clock,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${DateFormat('h:mm a').format(session.startTime)} - ${session.endTime != null ? DateFormat('h:mm a').format(session.endTime) : 'In Progress'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Performance metrics
              Row(
                children: [
                  Expanded(
                    child: _buildMetricChip(
                      context,
                      'Avg CPU',
                      '${session.averageCpuUsage.toStringAsFixed(1)}%',
                      AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricChip(
                      context,
                      'Avg Memory',
                      '${session.averageMemoryUsage.toStringAsFixed(1)}%',
                      AppTheme.accentTeal,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  _buildActionButton(
                    context,
                    LucideIcons.barChart3,
                    'View Chart',
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => RecordingDetailScreen(session: session),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    context,
                    LucideIcons.download,
                    'Export & Share',
                    () async {
                      await _showExportOptions(context, session);
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    context,
                    LucideIcons.trash2,
                    'Delete',
                    () async {
                      await _showDeleteDialog(context, session);
                    },
                    isDestructive: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricChip(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onPressed, {
    bool isDestructive = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDestructive 
                  ? AppTheme.warningRed.withValues(alpha: 0.3)
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 16,
                color: isDestructive 
                    ? AppTheme.warningRed
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDestructive 
                      ? AppTheme.warningRed
                      : Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  Future<void> _showExportOptions(BuildContext context, dynamic session) async {
    final provider = Provider.of<PerformanceProvider>(context, listen: false);
    await provider.fileExportService.showExportDialog(context, session);
  }

  Future<void> _showDeleteDialog(BuildContext context, dynamic session) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(LucideIcons.trash2, color: AppTheme.warningRed),
          title: const Text('Delete Recording'),
          content: const Text('Are you sure you want to delete this recording? This action cannot be undone.'),
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
              child: const Text('Delete'),
              onPressed: () async {
                Navigator.of(context).pop();
                final provider = Provider.of<PerformanceProvider>(context, listen: false);
                await provider.deleteSession(session.id);
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Recording deleted'),
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
}
