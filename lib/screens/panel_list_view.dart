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
  });

  final List<InspectionPanel> panels;
  final ValueChanged<InspectionPanel> onTap;

  @override
  Widget build(BuildContext context) {
    final attention = panels
        .where((p) =>
            p.status == PanelStatus.defect || p.status == PanelStatus.inProgress)
        .toList();
    final notStarted =
        panels.where((p) => p.status == PanelStatus.none).toList();
    final done = panels.where((p) => p.status == PanelStatus.done).toList();

    final groups = <(String, List<InspectionPanel>)>[
      ('Требует внимания', attention),
      ('Не начато', notStarted),
      ('Готово', done),
    ].where((g) => g.$2.isNotEmpty).toList();

    return ListView(
      // .scroll-body { padding: 4px 22px 18px }
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
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
                Text(title.toUpperCase(), style: AppText.sectionTitle),
                Text('${items.length}', style: AppText.sectionExtra),
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
          color: AppColors.bg1,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // .list-dot — квадратик 8×8 с радиусом 2, как в макете
            StatusDot(color: panel.status.color, size: 8),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    panel.name,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.text1,
                    ),
                  ),
                  // зоны в макете нет, но без неё теряется, где деталь
                  const SizedBox(height: 2),
                  Text(
                    panel.zone,
                    style: const TextStyle(fontSize: 10.5, color: AppColors.text3),
                  ),
                ],
              ),
            ),
            _Trailing(panel: panel),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 14, color: AppColors.text3),
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
            AppColors.statusDone.withValues(alpha: 0.14),
            AppColors.statusDone
          ),
        PanelCondition.satisfactory => (
            AppColors.statusProgress.withValues(alpha: 0.14),
            AppColors.statusProgress
          ),
        PanelCondition.needsRepair => (
            AppColors.statusDefect.withValues(alpha: 0.14),
            AppColors.statusDefect
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
        style: AppText.sectionExtra,
      );
    }

    return const SizedBox.shrink();
  }
}
