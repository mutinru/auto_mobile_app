import 'package:flutter/material.dart';

import '../models/inspection_panel.dart';
import '../models/panel_condition.dart';
import '../models/panel_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/status_dot.dart';

/// Экран 07 макета — «список».
///
/// Группировка по состоянию работы, а не по расположению на кузове:
/// список открывают, чтобы понять «что горит и что осталось», а геометрию
/// показывает вкладка «Схема». Пустые группы не рисуем.
class PanelListView extends StatelessWidget {
  const PanelListView({
    super.key,
    required this.panels,
    required this.onTap,
    this.embedded = false,
    this.forCustomer = false,
  });

  final List<InspectionPanel> panels;
  final ValueChanged<InspectionPanel> onTap;

  /// Внутри чужой прокрутки (отчёт заказчику): без своего скролла и отступов.
  final bool embedded;

  /// Заказчику важно не «что осталось сделать», а в каком состоянии
  /// машина — группируем по оценке, а не по ходу работы.
  final bool forCustomer;

  List<(String, List<InspectionPanel>)> _byWork() => [
    (
      'Требует внимания',
      panels
          .where(
            (p) =>
                p.status == PanelStatus.defect ||
                p.status == PanelStatus.inProgress,
          )
          .toList(),
    ),
    ('Не начато', panels.where((p) => p.status == PanelStatus.none).toList()),
    ('Готово', panels.where((p) => p.status == PanelStatus.done).toList()),
  ];

  List<(String, List<InspectionPanel>)> _byCondition() {
    List<InspectionPanel> having(Set<PanelCondition?> conditions) =>
        panels.where((p) => conditions.contains(p.condition)).toList();
    return [
      ('К ремонту', having({PanelCondition.needsRepair})),
      ('Есть замечания', having({PanelCondition.satisfactory})),
      ('В порядке', having({PanelCondition.excellent, PanelCondition.good})),
      ('Не оценено', having({null})),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final groups = (forCustomer ? _byCondition() : _byWork())
        .where((g) => g.$2.isNotEmpty)
        .toList();

    return ListView(
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      // .scroll-body { padding: 4px 22px 18px }
      padding: embedded
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(22, 4, 22, 18),
      children: [
        for (final (title, items) in groups) ...[
          // .list-group-head
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title.toUpperCase(), style: context.text.sectionTitle),
                Text('${items.length}', style: context.text.sectionExtra),
              ],
            ),
          ),
          for (final panel in items)
            _PanelRow(panel: panel, onTap: () => onTap(panel)),
        ],
      ],
    );
  }
}

/// .list-item
class _PanelRow extends StatelessWidget {
  const _PanelRow({required this.panel, required this.onTap});

  final InspectionPanel panel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.bg1,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // .list-dot — квадратик 8×8 с радиусом 2, как в макете
            StatusDot(color: panel.status.color(context.colors), size: 8),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    panel.name,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: context.colors.text1,
                    ),
                  ),
                  // зоны в макете нет, но без неё теряется, где деталь
                  const SizedBox(height: 2),
                  Text(
                    panel.zone,
                    style: TextStyle(fontSize: 10.5, color: context.colors.text3),
                  ),
                ],
              ),
            ),
            _Trailing(panel: panel),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 14, color: context.colors.text3),
          ],
        ),
      ),
    );
  }
}

/// Справа либо оценка (.list-grade), либо подсказка о работе (.list-tag):
/// пока оценки нет, полезнее показать, что по детали уже сделано.
class _Trailing extends StatelessWidget {
  const _Trailing({required this.panel});

  final InspectionPanel panel;

  @override
  Widget build(BuildContext context) {
    final condition = panel.condition;

    if (condition != null) {
      final (bg, fg) = switch (condition) {
        PanelCondition.excellent || PanelCondition.good => (
            context.colors.statusDone.withValues(alpha: 0.14),
            context.colors.statusDone
          ),
        PanelCondition.satisfactory => (
            context.colors.statusProgress.withValues(alpha: 0.14),
            context.colors.statusProgress
          ),
        PanelCondition.needsRepair => (
            context.colors.statusDefect.withValues(alpha: 0.14),
            context.colors.statusDefect
          ),
      };

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          condition.grade,
          style: TextStyle(
            fontFamily: AppTheme.monoFamily,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      );
    }

    if (panel.photoCount > 0) {
      return Text(
        '${panel.photoCount} фото',
        style: context.text.sectionExtra,
      );
    }

    return const SizedBox.shrink();
  }
}
