import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../data/models/recording_session.dart';
import '../design/components/surface.dart';
import '../design/palette.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../state/monitor_controller.dart';
import 'session_screen.dart';

/// List of saved recordings.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MonitorController>();
    final sessions = controller.sessions;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        const CupertinoSliverNavigationBar(largeTitle: Text('Recordings'), border: null),
        if (sessions.isEmpty)
          const SliverFillRemaining(hasScrollBody: false, child: _EmptyState())
        else
          SliverSafeArea(
            top: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.screenMargin,
                Spacing.sm,
                Spacing.screenMargin,
                Spacing.xxl,
              ),
              sliver: SliverList.separated(
                itemCount: sessions.length,
                separatorBuilder: (_, __) => const SizedBox(height: Spacing.md),
                itemBuilder: (context, index) => _SessionCard(session: sessions[index]),
              ),
            ),
          ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final RecordingSession session;

  @override
  Widget build(BuildContext context) {
    return Surface(
      onTap:
          () => Navigator.of(
            context,
          ).push(CupertinoPageRoute<void>(builder: (_) => SessionScreen(session: session))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _formatDate(session.startedAt.toLocal()),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.headline.copyWith(color: Palette.of(context, Palette.label)),
                      ),
                    ),
                    if (session.recoveredAfterCrash) ...[
                      const SizedBox(width: Spacing.sm),
                      const _RecoveredBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  '${_formatDuration(session.duration)} · ${session.sampleCount} '
                  '${session.sampleCount == 1 ? 'sample' : 'samples'} · every '
                  '${session.intervalSeconds}s',
                  style: AppText.subheadline.copyWith(
                    color: Palette.of(context, Palette.labelSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Icon(
            CupertinoIcons.chevron_forward,
            size: 16,
            color: Palette.of(context, Palette.labelTertiary),
          ),
        ],
      ),
    );
  }

  /// [value] must already be local; callers convert.
  static String _formatDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour < 12 ? 'AM' : 'PM';
    return '${months[value.month - 1]} ${value.day}, $hour:$minute $period';
  }

  static String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds;
    if (seconds < 60) return '${seconds}s';
    final minutes = duration.inMinutes;
    if (minutes < 60) return '${minutes}m ${seconds % 60}s';
    return '${duration.inHours}h ${minutes % 60}m';
  }
}

/// Marks a session that was closed out automatically after the app was killed.
class _RecoveredBadge extends StatelessWidget {
  const _RecoveredBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Palette.of(context, Palette.warning).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Radii.small),
      ),
      child: Text(
        'Recovered',
        style: AppText.caption2.copyWith(
          color: Palette.of(context, Palette.warning),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.chart_bar_alt_fill,
              size: 48,
              color: Palette.of(context, Palette.labelQuaternary),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              'No recordings yet',
              style: AppText.title3.copyWith(color: Palette.of(context, Palette.label)),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Start a recording from the Monitor tab to capture CPU, memory and battery over time.',
              textAlign: TextAlign.center,
              style: AppText.subheadline.copyWith(
                color: Palette.of(context, Palette.labelSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
