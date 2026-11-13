/// Чип фильтра и переключатель макета (design/app_auto_podbor.html).
library;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// .chip — переключаемая «таблетка». В app_auto_podbor.html активный
/// вариант оранжевый (st-progress), а не зелёный.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.on,
    this.onTap,
    this.activeColor,
    this.enabled = true,
    this.icon,
  });

  final String label;
  final bool on;
  final VoidCallback? onTap;

  /// Значок перед подписью — у чипа-действия, а не фильтра.
  final IconData? icon;

  /// false — чип виден, но не нажимается и приглушён.
  final bool enabled;

  /// null — оранжевый statusProgress текущей темы.
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final active = activeColor ?? context.colors.statusProgress;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: on ? active.withValues(alpha: 0.12) : context.colors.bg1,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: on ? active.withValues(alpha: 0.5) : context.colors.chipEdge,
          ),
        ),
        child: Builder(
          builder: (context) {
            final color = on
                ? context.colors.textFor(active)
                : (enabled ? context.colors.text2 : context.colors.text3);
            final text = Text(
              label,
              style: context.text.chip.copyWith(color: color),
            );
            if (icon == null) return text;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 5),
                text,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// .toggle — сегментированный переключатель под шапкой.
class AppToggle extends StatelessWidget {
  const AppToggle({
    super.key,
    required this.labels,
    required this.activeIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      // .toggle { margin: 0 22px 14px; padding: 3px; radius: 10px }
      margin: const EdgeInsets.fromLTRB(22, 0, 22, 14),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.colors.bg1,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(7),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == activeIndex
                        ? context.colors.bg3
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: i == activeIndex
                          ? context.colors.text1
                          : context.colors.text2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
