import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cpu_memory_tracking_app/providers/performance_provider.dart';
import 'package:cpu_memory_tracking_app/utils/theme.dart';

class RecordingDetailScreen extends StatelessWidget {
  final dynamic session; // RecordingSession type

  const RecordingDetailScreen({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recording Details'),
        actions: [
          Tooltip(
            message: 'Download CSV to Downloads folder',
            child: IconButton(
              icon: const Icon(LucideIcons.download),
              onPressed: () => _exportCsv(context),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.info,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Session Information',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      context,
                      'Start Time',
                      DateFormat('MMM d, y • h:mm a').format(session.startTime),
                    ),
                    _buildInfoRow(
                      context,
                      'End Time',
                      session.endTime != null 
                          ? DateFormat('MMM d, y • h:mm a').format(session.endTime)
                          : 'In Progress',
                    ),
                    _buildInfoRow(
                      context,
                      'Duration',
                      _formatDuration(session.duration),
                    ),
                    _buildInfoRow(
                      context,
                      'Data Points',
                      session.dataPoints.length.toString(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Performance Summary Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.barChart3,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Performance Summary',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            'Average CPU',
                            '${session.averageCpuUsage.toStringAsFixed(1)}%',
                            AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            'Maximum CPU',
                            '${session.maxCpuUsage.toStringAsFixed(1)}%',
                            AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            'Average Memory',
                            '${session.averageMemoryUsage.toStringAsFixed(1)}%',
                            AppTheme.accentTeal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            'Maximum Memory',
                            '${session.maxMemoryUsage.toStringAsFixed(1)}%',
                            AppTheme.accentTeal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            'Average Battery',
                            '${session.averageBatteryLevel.toStringAsFixed(1)}%',
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            'Min Battery',
                            '${session.minBatteryLevel.toStringAsFixed(1)}%',
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            'Max Battery Temp',
                            '${session.maxBatteryTemperature.toStringAsFixed(1)}°C',
                            Colors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            'Final Status',
                            session.finalBatteryStatus,
                            session.wasChargingDuringRecording ? Colors.green : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // CPU Chart
            _buildChartCard(
              context,
              'CPU Usage Over Time',
              LucideIcons.cpu,
              session.dataPoints,
              true, // isCpuChart
            ),

            const SizedBox(height: 16),

            // Memory Chart
            _buildChartCard(
              context,
              'Memory Usage Over Time',
              LucideIcons.hardDrive,
              session.dataPoints,
              false, // isMemoryChart
            ),

            const SizedBox(height: 16),

            // Battery Chart
            _buildBatteryChartCard(
              context,
              'Battery Level Over Time',
              LucideIcons.battery,
              session.dataPoints,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(
    BuildContext context,
    String title,
    IconData icon,
    List<dynamic> dataPoints,
    bool isCpuChart,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: _buildChart(context, dataPoints, isCpuChart),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context, List<dynamic> dataPoints, bool isCpuChart) {
    if (dataPoints.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final spots = dataPoints.asMap().entries.map((entry) {
      final value = isCpuChart 
          ? entry.value.cpuUsage 
          : entry.value.memoryUsage;
      return FlSpot(entry.key.toDouble(), value);
    }).toList();

    final color = isCpuChart ? AppTheme.primaryBlue : AppTheme.accentTeal;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 25,
          verticalInterval: dataPoints.length > 20 ? dataPoints.length / 10 : 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: dataPoints.length > 20 ? dataPoints.length / 5 : 5,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < dataPoints.length) {
                  final timestamp = dataPoints[value.toInt()].timestamp;
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      DateFormat('HH:mm').format(timestamp),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 25,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        minX: 0,
        maxX: dataPoints.length.toDouble() - 1,
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: dataPoints.length <= 50,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: color,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((touchedSpot) {
                final index = touchedSpot.x.toInt();
                if (index >= 0 && index < dataPoints.length) {
                  final dataPoint = dataPoints[index];
                  final time = DateFormat('HH:mm:ss').format(dataPoint.timestamp);
                  final value = isCpuChart ? dataPoint.cpuUsage : dataPoint.memoryUsage;
                  
                  return LineTooltipItem(
                    '$time\n${value.toStringAsFixed(1)}%',
                    TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }
                return null;
              }).toList();
            },
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

  Widget _buildBatteryChartCard(
    BuildContext context,
    String title,
    IconData icon,
    List<dynamic> dataPoints,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                // Legend for battery chart
                Row(
                  children: [
                    _buildChartLegend('Level', Colors.green),
                    const SizedBox(width: 16),
                    _buildChartLegend('Temp (×2)', Colors.orange),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: _buildBatteryChart(context, dataPoints),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildBatteryChart(BuildContext context, List<dynamic> dataPoints) {
    if (dataPoints.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final batterySpots = dataPoints.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.batteryLevel);
    }).toList();

    final tempSpots = dataPoints.asMap().entries.map((entry) {
      // Scale temperature to 0-100 range for visualization (assuming max temp around 50°C)
      final scaledTemp = (entry.value.batteryTemperature * 2).clamp(0.0, 100.0);
      return FlSpot(entry.key.toDouble(), scaledTemp);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 25,
          verticalInterval: dataPoints.length > 20 ? dataPoints.length / 10 : 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: dataPoints.length > 20 ? dataPoints.length / 5 : 5,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < dataPoints.length) {
                  final timestamp = dataPoints[value.toInt()].timestamp;
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      DateFormat('HH:mm').format(timestamp),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 25,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        minX: 0,
        maxX: (dataPoints.length - 1).toDouble(),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          // Battery level line
          LineChartBarData(
            spots: batterySpots,
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.withValues(alpha: 0.1),
            ),
          ),
          // Battery temperature line (scaled)
          LineChartBarData(
            spots: tempSpots,
            isCurved: true,
            color: Colors.orange,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
            dashArray: [5, 5], // Dashed line for temperature
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Exporting to Downloads...'),
            ],
          ),
        );
      },
    );

    try {
      final provider = Provider.of<PerformanceProvider>(context, listen: false);
      final filePath = await provider.exportSessionCsv(session.id);
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      // Extract just the filename from the full path for display
      final fileName = filePath.split('/').last;
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Export Successful!'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Saved to Downloads: $fileName',
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.error, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Export Failed'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _getErrorMessage(e.toString()),
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ),
            backgroundColor: AppTheme.warningRed,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('Storage permission denied')) {
      return 'Storage permission required. Please go to:\nSettings > Apps > SystemPulse > Permissions > Files and media > Allow\nOr try: Settings > Apps > SystemPulse > Permissions > Special app access > All files access > Allow';
    } else if (error.contains('Could not access Downloads folder')) {
      return 'Cannot access Downloads folder. This may be due to:\n• Storage permissions not granted\n• Device security restrictions\n• File system limitations\nTry granting all file permissions in Settings.';
    } else if (error.contains('Export failed')) {
      return 'CSV export failed. Please check:\n• Available storage space\n• App permissions in device settings\n• Try restarting the app if issue persists';
    } else {
      return 'Unexpected error occurred:\n$error\n\nPlease try again or restart the app.';
    }
  }
}
