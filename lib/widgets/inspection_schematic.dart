import 'package:flutter/material.dart';

import '../models/inspection_panel.dart';
import '../models/panel_status.dart';
import '../theme/app_colors.dart';
import 'car_schematic.dart';

/// Схема осмотра (экран 06 макета): кузов по центру и боковые колонки
/// .side-rail с пунктами вне кузова (kind = extra — двигатель, пороги,
/// окна, документы). Первые два extra-пункта — слева, остальные — справа,
/// в порядке, в котором их отдал сервер. У старых отчётов без extra-пунктов
/// колонок нет — остаётся одна схема кузова.
///
/// Колонки стоят в [Row], а не поверх схемы: кузов вписывается в остаток
/// ширины и не уходит под кнопки на узких экранах.
class InspectionSchematic extends StatelessWidget {
  const InspectionSchematic({
    super.key,
    required this.panels,
    required this.onTapPanel,
  });

  final List<InspectionPanel> panels;
  final ValueChanged<String> onTapPanel;

  @override
  Widget build(BuildContext context) {
    final car = CarSchematic(
      statuses: {for (final p in panels) p.id: p.status},
      onTapPanel: onTapPanel,
    );
    final extra = panels.where((p) => p.isExtra).toList();
    if (extra.isEmpty) return car;

    final split = extra.length < 2 ? extra.length : 2;
    return Row(
      children: [
        _SideRail(panels: extra.sublist(0, split), onTap: onTapPanel),
        const SizedBox(width: 8),
        Expanded(child: car),
        const SizedBox(width: 8),
        _SideRail(panels: extra.sublist(split), onTap: onTapPanel),
      ],
    );
  }
}

/// .side-rail — колонка кнопок по центру высоты, gap 8.
class _SideRail extends StatelessWidget {
  const _SideRail({required this.panels, required this.onTap});

  final List<InspectionPanel> panels;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    // На низкой схеме (отчёт, маленький экран) колонка ужимается целиком,
    // а не вылезает за край.
    return SizedBox(
      width: 38,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 38,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, p) in panels.indexed) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _SideRailButton(panel: p, onTap: () => onTap(p.id)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// .side-btn — точка статуса и подпись снизу вверх.
class _SideRailButton extends StatelessWidget {
  const _SideRailButton({required this.panel, required this.onTap});

  final InspectionPanel panel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(13);
    return Semantics(
      button: true,
      label: '${panel.name}: ${panel.status.label}',
      excludeSemantics: true,
      child: Material(
        color: context.colors.bg1,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: context.colors.line),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 18),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: panel.status.color(context.colors),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 10),
                  RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      panel.name,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.24,
                        color: context.colors.text2,
                      ),
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
