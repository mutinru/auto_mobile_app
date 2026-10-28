import 'package:flutter/material.dart';

import '../models/inspection_panel.dart';
import '../models/panel_status.dart';
import '../theme/app_colors.dart';
import 'status_dot.dart';

/// Блок "X/Total деталей оценено" + сегментированный прогресс-бар + легенда.
/// Соответствует .progress-block из макета.
class ProgressSummary extends StatelessWidget {
  const ProgressSummary({super.key, required this.panels});

  final List<InspectionPanel> panels;

  int get _evaluated =>
      panels.where((p) => p.status != PanelStatus.none).length;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.colors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$_evaluated',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: context.colors.text1,
                ),
              ),
              Text(
                ' / ',
                style: TextStyle(color: context.colors.text3, fontSize: 22),
              ),
              Text(
                '${panels.length}',
                style: TextStyle(color: context.colors.text3, fontSize: 22),
              ),
              const SizedBox(width: 10),
              Text(
                'деталей оценено',
                style: TextStyle(color: context.colors.text2, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: Row(
                children: [
                  for (final p in panels) ...[
                    Expanded(child: Container(color: p.status.color(context.colors))),
                    if (p != panels.last) const SizedBox(width: 2),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              for (final status in PanelStatus.values)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusDot(color: status.color(context.colors)),
                    const SizedBox(width: 6),
                    Text(
                      status.label,
                      style: TextStyle(
                        color: context.colors.text2,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
