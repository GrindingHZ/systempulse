import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../palette.dart';
import '../tokens.dart';
import '../typography.dart';

/// The primary control: starts and stops a recording.
///
/// Modelled on the iOS camera shutter. The outer ring is constant while the inner shape morphs
/// between a filled circle (idle, "will start") and a rounded square (recording, "will stop").
/// A single control that changes shape rather than two alternating buttons means the target never
/// moves under the user's thumb, and the shape itself carries the state.
class RecordButton extends StatefulWidget {
  const RecordButton({
    super.key,
    required this.isRecording,
    required this.onPressed,
    this.enabled = true,
  });

  final bool isRecording;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton> with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: Motion.fast,
    reverseDuration: Motion.medium,
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.enabled) return;
    // A recording starting or stopping is a consequential, non-visual state change. A light impact
    // confirms it happened without the user needing to look, which is exactly what haptics are for
    // on iOS. Overusing them on every tap is what makes an interface feel cheap, so this is the
    // only place the app fires one.
    unawaited(HapticFeedback.mediumImpact());
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Palette.of(context, Palette.danger);
    final ringColor = Palette.of(context, Palette.separator);

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.isRecording ? 'Stop recording' : 'Start recording',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled ? (_) => _press.forward() : null,
        onTapUp: widget.enabled ? (_) => _press.reverse() : null,
        onTapCancel: widget.enabled ? () => _press.reverse() : null,
        onTap: _handleTap,
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 1,
            end: 0.93,
          ).animate(CurvedAnimation(parent: _press, curve: Curves.easeOut)),
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.4,
            child: SizedBox(
              width: 76,
              height: 76,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ringColor, width: 3),
                    ),
                  ),
                  // The inner shape animates size and corner radius together, so a circle becomes a
                  // square without a discontinuity at any point in between.
                  AnimatedContainer(
                    duration: Motion.medium,
                    curve: Motion.standard,
                    width: widget.isRecording ? 28 : 60,
                    height: widget.isRecording ? 28 : 60,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(widget.isRecording ? 7 : 30),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Elapsed-time readout shown beside the record button while a session runs.
///
/// Rebuilt from a ticker rather than from the sampling stream, so the clock advances smoothly at
/// one hertz regardless of how often samples arrive.
class ElapsedLabel extends StatefulWidget {
  const ElapsedLabel({super.key, required this.since, required this.isRunning});

  final DateTime? since;
  final bool isRunning;

  @override
  State<ElapsedLabel> createState() => _ElapsedLabelState();
}

class _ElapsedLabelState extends State<ElapsedLabel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(ElapsedLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRunning != widget.isRunning) _syncTicker();
  }

  void _syncTicker() {
    _ticker?.cancel();
    _ticker = null;
    if (!widget.isRunning) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final since = widget.since;
    // `since` is UTC, so `now` must be too; differencing a local against a UTC DateTime would be
    // wrong by the local offset.
    final elapsed = since == null ? Duration.zero : DateTime.now().toUtc().difference(since);

    return Text(
      _format(elapsed),
      style: AppText.metricValueSmall.copyWith(
        color: Palette.of(context, widget.isRunning ? Palette.label : Palette.labelTertiary),
      ),
    );
  }

  static String _format(Duration duration) {
    final seconds = duration.inSeconds.clamp(0, 999 * 3600);
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remaining = seconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = remaining.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }
}
