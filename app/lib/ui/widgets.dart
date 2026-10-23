import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Small uppercase mono caption above a group.
class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2, right: 2, top: 4),
        child: Row(
          children: [
            Text(text.toUpperCase(), style: T.label),
            if (trailing != null) ...[const Spacer(), trailing!],
          ],
        ),
      );
}

/// Flat rounded button in the console style.
class ConsoleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool primary;
  final bool danger;
  final double height;
  final EdgeInsets padding;
  final Color? background;

  const ConsoleButton({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.primary = false,
    this.danger = false,
    this.height = 48,
    this.padding = const EdgeInsets.symmetric(horizontal: 14),
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final bg = background ?? (primary ? T.accent : T.surface2);
    final fg = primary ? T.bg : (danger ? T.danger : T.text2);
    return Material(
      color: bg,
      borderRadius: T.r12,
      child: InkWell(
        borderRadius: T.r12,
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        onLongPress: onLongPress,
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: T.r12,
            border: Border.all(color: primary ? T.accent : T.line2),
          ),
          alignment: Alignment.center,
          child: DefaultTextStyle(
            style: TextStyle(
              fontFamily: T.sans,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: fg,
            ),
            child: IconTheme(data: IconThemeData(color: fg, size: 18), child: child),
          ),
        ),
      ),
    );
  }
}

/// Square icon button used in headers.
class IconSquare extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool selected;
  final String? tooltip;
  const IconSquare(this.icon, {super.key, this.onTap, this.selected = false, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final w = Material(
      color: selected ? T.accent : T.surface2,
      borderRadius: T.r10,
      child: InkWell(
        borderRadius: T.r10,
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: T.r10,
            border: Border.all(color: selected ? T.accent : T.line),
          ),
          child: Icon(icon, size: 20, color: selected ? T.bg : T.text2),
        ),
      ),
    );
    return tooltip == null ? w : Tooltip(message: tooltip!, child: w);
  }
}

/// Mono key-cap chip (Esc, Tab, Ctrl+C ...).
class KeyChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const KeyChip(this.label, {super.key, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: T.surface3,
        borderRadius: T.r10,
        child: InkWell(
          borderRadius: T.r10,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(borderRadius: T.r10, border: Border.all(color: T.line2)),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(fontFamily: T.mono, fontSize: 12, color: T.text2),
            ),
          ),
        ),
      );
}

/// Bordered surface card.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: T.r14,
          border: Border.all(color: T.line),
        ),
        child: child,
      );
}

/// Segmented control, mono labels.
class Segmented<V> extends StatelessWidget {
  final List<(V, String)> options;
  final V value;
  final ValueChanged<V> onChanged;
  const Segmented({super.key, required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: T.surface, borderRadius: T.r12, border: Border.all(color: T.line)),
        child: Row(
          children: [
            for (final (v, label) in options)
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(v);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 36,
                    decoration: BoxDecoration(
                      color: v == value ? T.accent : Colors.transparent,
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontFamily: T.mono,
                        fontSize: 11,
                        letterSpacing: 1,
                        color: v == value ? T.bg : T.muted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

/// Pulsing status dot.
class StatusDot extends StatelessWidget {
  final Color color;
  const StatusDot({super.key, this.color = T.accent});

  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 10)],
        ),
      );
}

void showSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}
