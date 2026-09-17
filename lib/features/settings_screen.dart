import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../data/sources/settings_store.dart';
import '../design/components/rows.dart';
import '../design/components/surface.dart';
import '../design/palette.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../state/monitor_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MonitorController>();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        const CupertinoSliverNavigationBar(largeTitle: Text('Settings'), border: null),
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
                const SectionHeader('Sampling'),
                _IntervalPicker(controller: controller),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, 0),
                  child: Text(
                    controller.isRecording
                        ? 'Changing this restarts sampling for the recording in progress.'
                        : 'How often a sample is taken while recording. Shorter intervals produce '
                            'larger files and cost more battery.',
                    style: AppText.caption1.copyWith(
                      color: Palette.of(context, Palette.labelSecondary),
                    ),
                  ),
                ),
                const SectionHeader('Appearance'),
                _ThemePicker(controller: controller),
                const SectionHeader('Live chart'),
                RowGroup(
                  children: [
                    ValueRow(
                      label: 'Window',
                      value: '${controller.chartWindowSeconds}s',
                      monospaceValue: true,
                      onTap: () => _pickChartWindow(context, controller),
                    ),
                  ],
                ),
                const SectionHeader('About'),
                const RowGroup(
                  children: [
                    ValueRow(label: 'App CPU', value: 'Process CPU time'),
                    ValueRow(label: 'Device memory', value: 'Total − available'),
                    ValueRow(label: 'App memory', value: 'Proportional set size'),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(Spacing.lg, Spacing.sm, Spacing.lg, 0),
                  child: Text(
                    'App CPU is this process’s CPU time divided by elapsed time and core '
                    'count — the same definition top uses. It is not derived from clock frequency.',
                    style: AppText.caption1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickChartWindow(BuildContext context, MonitorController controller) async {
    const options = [30, 60, 120, 300];
    final choice = await showCupertinoModalPopup<int>(
      context: context,
      builder:
          (context) => CupertinoActionSheet(
            title: const Text('Live chart window'),
            actions: [
              for (final seconds in options)
                CupertinoActionSheetAction(
                  onPressed: () => Navigator.of(context).pop(seconds),
                  child: Text(seconds < 60 ? '$seconds seconds' : '${seconds ~/ 60} minutes'),
                ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
    );
    if (choice != null) await controller.setChartWindow(choice);
  }
}

/// Segmented control over the supported sampling intervals.
class _IntervalPicker extends StatelessWidget {
  const _IntervalPicker({required this.controller});

  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    return Surface(
      padding: const EdgeInsets.all(Spacing.sm),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<int>(
          groupValue: controller.intervalSeconds,
          onValueChanged: (value) {
            if (value != null) unawaited(controller.setInterval(value));
          },
          children: {
            for (final seconds in SettingsStore.allowedIntervals)
              seconds: Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                child: Text(
                  seconds == 60 ? '1m' : '${seconds}s',
                  style: AppText.footnote.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
          },
        ),
      ),
    );
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.controller});

  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    // Null is "follow the system", which is the default and what the control shows as Automatic.
    const values = <int, Brightness?>{0: null, 1: Brightness.light, 2: Brightness.dark};
    final current =
        values.entries.firstWhere((entry) => entry.value == controller.themeOverride).key;

    return Surface(
      padding: const EdgeInsets.all(Spacing.sm),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<int>(
          groupValue: current,
          onValueChanged: (value) {
            if (value != null) unawaited(controller.setThemeOverride(values[value]));
          },
          children: {0: _label('Automatic'), 1: _label('Light'), 2: _label('Dark')},
        ),
      ),
    );
  }

  static Widget _label(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
    child: Text(text, style: AppText.footnote.copyWith(fontWeight: FontWeight.w600)),
  );
}
