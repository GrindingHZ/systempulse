import 'package:flutter/cupertino.dart';

import '../palette.dart';
import '../tokens.dart';
import '../typography.dart';
import 'surface.dart';

/// A label-and-value row, as used throughout iOS Settings.
class ValueRow extends StatelessWidget {
  const ValueRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
    this.onTap,
    this.valueColor,
    this.monospaceValue = false,
  });

  final String label;

  /// Null renders as an em dash, meaning the device did not report this. Nothing is invented to
  /// fill the gap.
  final String? value;

  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final Color? valueColor;

  /// Use for figures that update or that read as a column, so digits keep a fixed width.
  final bool monospaceValue;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: Palette.of(context, iconColor ?? Palette.labelSecondary)),
            const SizedBox(width: Spacing.md),
          ],
          Expanded(
            child: Text(
              label,
              style: AppText.body.copyWith(color: Palette.of(context, Palette.label)),
            ),
          ),
          const SizedBox(width: Spacing.md),
          Flexible(
            child: Text(
              hasValue ? value! : '—',
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: (monospaceValue ? AppText.monoBody : AppText.body).copyWith(
                color: Palette.of(
                  context,
                  hasValue ? (valueColor ?? Palette.labelSecondary) : Palette.labelQuaternary,
                ),
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: Spacing.xs),
            Icon(
              CupertinoIcons.chevron_forward,
              size: 16,
              color: Palette.of(context, Palette.labelTertiary),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: content);
  }
}

/// Groups rows into one rounded surface, inserting inset hairlines between them.
///
/// Callers pass the rows themselves; the separators are this widget's responsibility, which means
/// a row can never be added without one or end up with a trailing rule below the last item.
class RowGroup extends StatelessWidget {
  const RowGroup({
    super.key,
    required this.children,
    this.separatorIndent = Spacing.separatorInset,
  });

  final List<Widget> children;
  final double separatorIndent;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final interleaved = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      interleaved.add(children[i]);
      if (i != children.length - 1) {
        interleaved.add(Hairline(indent: separatorIndent));
      }
    }

    return Surface(
      padding: EdgeInsets.zero,
      child: Column(mainAxisSize: MainAxisSize.min, children: interleaved),
    );
  }
}

/// A row whose trailing control is a switch.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.caption,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppText.body.copyWith(color: Palette.of(context, Palette.label)),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    caption!,
                    style: AppText.footnote.copyWith(
                      color: Palette.of(context, Palette.labelSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Spacing.md),
          CupertinoSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
