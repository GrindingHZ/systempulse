import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../data/models/recording_session.dart';
import '../data/sources/metrics_channel.dart';
import '../design/components/rows.dart';
import '../design/components/sparkline.dart';
import '../design/components/surface.dart';
import '../design/palette.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../state/monitor_controller.dart';

/// One recording in detail: charts, summary statistics and export.
///
/// Samples are loaded here rather than being carried in the session object, so opening a long
/// recording costs one read and the history list stays cheap regardless of how much data exists.
class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.session});

  final RecordingSession session;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late Future<SessionDetail> _detail;

  @override
  void initState() {
    super.initState();
    _detail = context.read<MonitorController>().loadSession(widget.session);
  }

  Future<void> _export() async {
    final controller = context.read<MonitorController>();
    try {
      final location = await controller.exportSession(widget.session);
      if (!mounted) return;
      await _alert('Exported', 'Saved to $location');
    } on MetricsUnavailable catch (error) {
      if (!mounted) return;
      await _alert('Export failed', error.message);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder:
          (context) => CupertinoActionSheet(
            title: const Text('Delete this recording?'),
            message: const Text('The recording and its samples will be removed from this device.'),
            actions: [
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ),
    );

    if (confirmed != true || !mounted) return;
    await context.read<MonitorController>().deleteSession(widget.session.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _alert(String title, String message) => showCupertinoDialog<void>(
    context: context,
    builder:
        (context) => CupertinoAlertDialog(
          title: Text(title),
          content: Padding(padding: const EdgeInsets.only(top: Spacing.sm), child: Text(message)),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
  );

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Palette.of(context, Palette.canvas),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Recording'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          onPressed: _export,
          child: const Icon(CupertinoIcons.square_arrow_up, size: 22),
        ),
      ),
      child: FutureBuilder<SessionDetail>(
        future: _detail,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CupertinoActivityIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.xxl),
                child: Text(
                  'This recording could not be read.',
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: Palette.of(context, Palette.labelSecondary)),
                ),
              ),
            );
          }
          return _DetailBody(detail: snapshot.data!, onDelete: _confirmDelete);
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail, required this.onDelete});

  final SessionDetail detail;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final session = detail.session;
    final samples = detail.samples;

    if (samples.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xxl),
          child: Text(
            'This recording contains no samples.',
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: Palette.of(context, Palette.labelSecondary)),
          ),
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(
        Spacing.screenMargin,
        Spacing.lg,
        Spacing.screenMargin,
        Spacing.xxl,
      ),
      children: [
        RowGroup(
          children: [
            ValueRow(
              label: 'Started',
              value: session.startedAt.toLocal().toString().split('.').first,
              monospaceValue: true,
            ),
            ValueRow(
              label: 'Duration',
              value: _formatDuration(session.duration),
              monospaceValue: true,
            ),
            ValueRow(label: 'Samples', value: '${samples.length}', monospaceValue: true),
            ValueRow(label: 'Interval', value: '${session.intervalSeconds}s', monospaceValue: true),
            if (detail.sawLowMemory)
              const ValueRow(
                label: 'Memory pressure',
                value: 'Reported during session',
                valueColor: Palette.warning,
              ),
          ],
        ),
        _ChartSection(
          title: 'App CPU',
          unit: '%',
          color: Palette.cpu,
          summary: detail.cpu,
          values: [for (final s in samples) s.cpuPercent],
        ),
        _ChartSection(
          title: 'Device memory',
          unit: '%',
          color: Palette.memory,
          summary: detail.deviceMemory,
          values: [for (final s in samples) s.deviceMemoryPercent],
        ),
        _ChartSection(
          title: 'Battery',
          unit: '%',
          color: Palette.battery,
          summary: detail.battery,
          values: [for (final s in samples) s.batteryPercent],
        ),
        _ChartSection(
          title: 'Battery temperature',
          unit: '°C',
          color: Palette.temperature,
          summary: detail.temperature,
          values: [for (final s in samples) s.batteryTemperatureC],
          maximum: 60,
        ),
        const SizedBox(height: Spacing.xl),
        Surface(
          padding: EdgeInsets.zero,
          child: CupertinoButton(
            onPressed: onDelete,
            child: Text(
              'Delete Recording',
              style: AppText.body.copyWith(color: Palette.of(context, Palette.danger)),
            ),
          ),
        ),
      ],
    );
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }
}

/// A chart with its own min/average/max readout.
///
/// A section is shown only when the metric actually has readings. A chart of an entirely
/// unavailable metric would be a flat line at zero, which looks like measured data.
class _ChartSection extends StatelessWidget {
  const _ChartSection({
    required this.title,
    required this.unit,
    required this.color,
    required this.summary,
    required this.values,
    this.maximum = 100,
  });

  final String title;
  final String unit;
  final Color color;
  final MetricSummary summary;
  final List<double?> values;
  final double maximum;

  @override
  Widget build(BuildContext context) {
    if (!summary.hasData) return const SizedBox.shrink();
    final resolved = Palette.of(context, color);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title),
        Surface(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 120,
                width: double.infinity,
                child: Sparkline(values: values, color: resolved, maximum: maximum, strokeWidth: 2),
              ),
              const SizedBox(height: Spacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Stat(label: 'Min', value: summary.minimum, unit: unit),
                  _Stat(label: 'Avg', value: summary.average, unit: unit),
                  _Stat(label: 'Max', value: summary.maximum, unit: unit, emphasise: true),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.unit,
    this.emphasise = false,
  });

  final String label;
  final double value;
  final String unit;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: AppText.caption2.copyWith(
            color: Palette.of(context, Palette.labelTertiary),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${value.toStringAsFixed(1)}$unit',
          style: AppText.monoBody.copyWith(
            fontWeight: emphasise ? FontWeight.w600 : FontWeight.w400,
            color: Palette.of(context, Palette.label),
          ),
        ),
      ],
    );
  }
}
