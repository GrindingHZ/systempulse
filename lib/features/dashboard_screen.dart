import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../data/models/metric_sample.dart';
import '../design/components/metric_tile.dart';
import '../design/components/record_button.dart';
import '../design/components/rows.dart';
import '../design/components/surface.dart';
import '../design/palette.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../state/monitor_controller.dart';

/// The live view: current readings, recent history, and the record control.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MonitorController>();
    final sample = controller.latest;
    final window = controller.liveWindow;

    return CustomScrollView(
      // Bouncing physics are not decoration: the rubber-band response at the end of a scroll is one
      // of the most recognisable parts of how iOS feels, and its absence is noticed even by people
      // who could not name it.
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        const CupertinoSliverNavigationBar(largeTitle: Text('SystemPulse'), border: null),
        SliverSafeArea(
          top: false,
          sliver: SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.screenMargin,
              Spacing.sm,
              Spacing.screenMargin,
              Spacing.xxl,
            ),
            sliver: SliverList.list(
              children: [
                if (controller.recoveredSessions.isNotEmpty)
                  _RecoveryNotice(
                    count: controller.recoveredSessions.length,
                    onDismiss: controller.acknowledgeRecovery,
                  ),
                _StatusStrip(status: controller.status, detail: controller.statusDetail),
                const SizedBox(height: Spacing.lg),
                _RecordPanel(controller: controller),
                const SizedBox(height: Spacing.xl),
                _MetricGrid(sample: sample, window: window, controller: controller),
                const SizedBox(height: Spacing.xl),
                _DetailGroup(sample: sample),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A one-line explanation of why the numbers are not updating, shown only when that is the case.
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.status, required this.detail});

  final LiveStatus status;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final (String text, Color color, IconData icon) = switch (status) {
      LiveStatus.live => (
        'Live',
        Palette.of(context, Palette.success),
        CupertinoIcons.dot_radiowaves_left_right,
      ),
      LiveStatus.starting => (
        'Starting…',
        Palette.of(context, Palette.labelSecondary),
        CupertinoIcons.clock,
      ),
      LiveStatus.paused => (
        'Paused in background',
        Palette.of(context, Palette.labelSecondary),
        CupertinoIcons.pause_circle,
      ),
      LiveStatus.unavailable => (
        detail ?? 'Readings unavailable on this device',
        Palette.of(context, Palette.warning),
        CupertinoIcons.exclamationmark_triangle,
      ),
    };

    return AnimatedSwitcher(
      duration: Motion.medium,
      child: Row(
        key: ValueKey(status),
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: Spacing.xs + 2),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              style: AppText.footnote.copyWith(color: color, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordPanel extends StatelessWidget {
  const _RecordPanel({required this.controller});

  final MonitorController controller;

  Future<void> _toggle(BuildContext context) async {
    if (controller.isRecording) {
      await controller.stopRecording();
      return;
    }

    final error = await controller.startRecording();
    if (error != null && context.mounted) {
      await showCupertinoDialog<void>(
        context: context,
        builder:
            (context) => CupertinoAlertDialog(
              title: const Text('Could not start recording'),
              content: Padding(padding: const EdgeInsets.only(top: Spacing.sm), child: Text(error)),
              actions: [
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = controller.activeSession;
    final recording = controller.isRecording;

    return Surface(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.lg),
      child: Row(
        children: [
          RecordButton(isRecording: recording, onPressed: () => _toggle(context)),
          const SizedBox(width: Spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  recording ? 'Recording' : 'Ready',
                  style: AppText.headline.copyWith(color: Palette.of(context, Palette.label)),
                ),
                const SizedBox(height: 2),
                ElapsedLabel(since: session?.startedAt, isRunning: recording),
                const SizedBox(height: 2),
                Text(
                  recording
                      ? 'Sampling every ${_intervalLabel(controller.intervalSeconds)} · continues in the background'
                      : 'Samples every ${_intervalLabel(controller.intervalSeconds)}',
                  style: AppText.caption1.copyWith(
                    color: Palette.of(context, Palette.labelTertiary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _intervalLabel(int seconds) =>
      seconds == 1
          ? 'second'
          : seconds == 60
          ? 'minute'
          : '$seconds seconds';
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.sample, required this.window, required this.controller});

  final MetricSample? sample;
  final List<MetricSample> window;
  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    final batteryLevel = sample?.batteryPercent;

    return Column(
      children: [
        // IntrinsicHeight lets the two tiles in a row share the height of the taller one. Without
        // it, `CrossAxisAlignment.stretch` asks for the row's full cross-axis extent, which inside
        // a vertically scrolling viewport is unbounded — an assertion failure, not a tall tile.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: MetricTile(
                  label: 'App CPU',
                  value: sample?.cpuPercent,
                  unit: '%',
                  color: Palette.cpu,
                  history: [for (final s in window) s.cpuPercent],
                  caption: _cpuCaption(sample),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: MetricTile(
                  label: 'Device memory',
                  value: sample?.deviceMemoryPercent,
                  unit: '%',
                  color: Palette.memory,
                  history: [for (final s in window) s.deviceMemoryPercent],
                  caption: _memoryCaption(sample),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: MetricTile(
                  label: 'Battery',
                  value: batteryLevel,
                  unit: '%',
                  color: Palette.battery,
                  history: [for (final s in window) s.batteryPercent],
                  caption: sample?.batteryStatus,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: MetricTile(
                  label: 'Battery temp',
                  value: sample?.batteryTemperatureC,
                  unit: '°C',
                  color: Palette.temperature,
                  minimum: 0,
                  maximum: 60,
                  history: [for (final s in window) s.batteryTemperatureC],
                  caption: _temperatureCaption(sample?.batteryTemperatureC),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Says what the CPU figure means, because "CPU %" is ambiguous on a multi-core device.
  static String? _cpuCaption(MetricSample? sample) {
    final perCore = sample?.cpuPerCorePercent;
    if (perCore == null) return null;
    return '${perCore.toStringAsFixed(0)}% of one core';
  }

  static String? _memoryCaption(MetricSample? sample) {
    final used = sample?.deviceMemoryUsedBytes;
    final total = sample?.deviceMemoryTotalBytes;
    if (used == null || total == null || total <= 0) return null;
    return '${_gigabytes(used)} of ${_gigabytes(total)}';
  }

  static String? _temperatureCaption(double? celsius) {
    if (celsius == null) return null;
    if (celsius >= 45) return 'Hot';
    if (celsius >= 38) return 'Warm';
    return 'Normal';
  }

  static String _gigabytes(int bytes) => '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

class _DetailGroup extends StatelessWidget {
  const _DetailGroup({required this.sample});

  final MetricSample? sample;

  @override
  Widget build(BuildContext context) {
    final appMemory = sample?.appMemoryBytes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: Spacing.xs, bottom: Spacing.sm),
          child: SectionHeader('This app'),
        ),
        RowGroup(
          children: [
            ValueRow(
              label: 'Memory footprint',
              value:
                  appMemory == null ? null : '${(appMemory / (1024 * 1024)).toStringAsFixed(0)} MB',
              monospaceValue: true,
            ),
            ValueRow(
              label: 'CPU, one core',
              value:
                  sample?.cpuPerCorePercent == null
                      ? null
                      : '${sample!.cpuPerCorePercent!.toStringAsFixed(1)}%',
              monospaceValue: true,
            ),
            ValueRow(
              label: 'Memory pressure',
              value: sample == null ? null : (sample!.deviceLowMemory ? 'Low memory' : 'Normal'),
              valueColor: sample?.deviceLowMemory == true ? Palette.danger : null,
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, 0),
          child: Text(
            'App CPU is process CPU time divided by elapsed time and core count. Device memory '
            'counts reclaimable cache as used, so a healthy device reads high.',
            style: AppText.caption1,
          ),
        ),
      ],
    );
  }
}

/// Shown once after the app was killed mid-recording.
class _RecoveryNotice extends StatelessWidget {
  const _RecoveryNotice({required this.count, required this.onDismiss});

  final int count;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Surface(
        color: Palette.surface,
        child: Row(
          children: [
            Icon(
              CupertinoIcons.checkmark_shield,
              size: 22,
              color: Palette.of(context, Palette.success),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Text(
                count == 1
                    ? 'A recording interrupted last time was recovered and saved.'
                    : '$count interrupted recordings were recovered and saved.',
                style: AppText.footnote.copyWith(color: Palette.of(context, Palette.label)),
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
              onPressed: onDismiss,
              child: Icon(
                CupertinoIcons.xmark_circle_fill,
                size: 20,
                color: Palette.of(context, Palette.labelTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
