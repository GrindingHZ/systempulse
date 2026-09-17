import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../data/models/device_profile.dart';
import '../design/components/rows.dart';
import '../design/components/surface.dart';
import '../design/palette.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../state/monitor_controller.dart';

/// Hardware facts about this device.
///
/// Rows whose value is unknown render an em dash. Nothing here is inferred from core count or any
/// other proxy — the screen this replaces presented invented processor names and clock speeds to
/// users as their own hardware.
class DeviceScreen extends StatelessWidget {
  const DeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final device = context.watch<MonitorController>().device;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        const CupertinoSliverNavigationBar(largeTitle: Text('Device'), border: null),
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
              children: device == null ? const [_Unavailable()] : [_DeviceBody(device: device)],
            ),
          ),
        ),
      ],
    );
  }
}

class _DeviceBody extends StatelessWidget {
  const _DeviceBody({required this.device});

  final DeviceProfile device;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Surface(
          child: Row(
            children: [
              Icon(
                CupertinoIcons.device_phone_portrait,
                size: 32,
                color: Palette.of(context, Palette.accent),
              ),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      device.displayName ?? 'Unknown device',
                      style: AppText.title3.copyWith(color: Palette.of(context, Palette.label)),
                    ),
                    if (device.androidRelease != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Android ${device.androidRelease}'
                        '${device.sdkInt != null ? ' · API ${device.sdkInt}' : ''}',
                        style: AppText.subheadline.copyWith(
                          color: Palette.of(context, Palette.labelSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SectionHeader('Processor'),
        RowGroup(
          children: [
            ValueRow(label: 'Cores', value: device.coreCount?.toString(), monospaceValue: true),
            ValueRow(
              label: 'Peak clock',
              value:
                  device.maxCpuFrequencyMhz == null
                      ? null
                      : '${(device.maxCpuFrequencyMhz! / 1000).toStringAsFixed(2)} GHz',
              monospaceValue: true,
            ),
            ValueRow(label: 'Architecture', value: device.primaryAbi),
            ValueRow(label: 'Chipset', value: device.hardware),
            ValueRow(label: 'Board', value: device.board),
          ],
        ),
        const SectionHeader('Memory'),
        RowGroup(
          children: [
            ValueRow(
              label: 'Total RAM',
              value:
                  device.totalRamBytes == null
                      ? null
                      : '${(device.totalRamBytes! / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB',
              monospaceValue: true,
            ),
          ],
        ),
        const SectionHeader('Display'),
        RowGroup(
          children: [
            ValueRow(
              label: 'Resolution',
              value:
                  device.screenWidthPx == null || device.screenHeightPx == null
                      ? null
                      : '${device.screenWidthPx} × ${device.screenHeightPx}',
              monospaceValue: true,
            ),
            ValueRow(
              label: 'Density',
              value: device.screenDensityDpi == null ? null : '${device.screenDensityDpi} dpi',
              monospaceValue: true,
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, 0),
          child: Text(
            'A dash means the device does not report that value to apps. Nothing on this screen is '
            'estimated.',
            style: AppText.caption1,
          ),
        ),
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xxl * 2),
      child: Column(
        children: [
          const CupertinoActivityIndicator(),
          const SizedBox(height: Spacing.lg),
          Text(
            'Reading device information…',
            style: AppText.subheadline.copyWith(color: Palette.of(context, Palette.labelSecondary)),
          ),
        ],
      ),
    );
  }
}
