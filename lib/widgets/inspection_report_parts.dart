import 'package:flutter/material.dart';

import '../models/inspection_panel.dart';
import '../models/panel_condition.dart';
import '../models/panel_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'score_ring.dart';

/// Общие куски отчёта осмотра — у исполнителя в сводке
/// ([InspectionSummaryScreen]) и у заказчика ([InspectionReportScreen]).

/// Балл считаем из оценок деталей: у макета в этом месте «78», но
/// откуда он берётся, дизайн не описывает. Веса подобраны так, чтобы
/// A/B давали «хорошо», C тянул вниз, D — сильно вниз.
int reportScoreOf(List<InspectionPanel> panels) {
  final assessed = panels.where((p) => p.condition != null).toList();
  if (assessed.isEmpty) return 0;
  final sum = assessed.fold<int>(0, (acc, p) {
    return acc +
        switch (p.condition!) {
          PanelCondition.excellent => 100,
          PanelCondition.good => 85,
          PanelCondition.satisfactory => 60,
          PanelCondition.needsRepair => 25,
        };
  });
  return (sum / assessed.length).round();
}

String reportGradeOf(int score) {
  if (score >= 85) return 'Отличное состояние';
  if (score >= 70) return 'Хорошее состояние';
  if (score >= 50) return 'Удовлетворительное';
  return 'Требует ремонта';
}

/// Детали, которые попадают в «Найденные дефекты».
List<InspectionPanel> defectivePanels(List<InspectionPanel> panels) => panels
    .where((p) => p.status == PanelStatus.defect || p.defects.isNotEmpty)
    .toList();

/// «1 деталь», «3 детали», «5 деталей» — для подписи под счётчиком.
String panelsWord(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return 'деталь';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'детали';
  }
  return 'деталей';
}

/// .score-card — кольцо с баллом и словесная оценка.
class ReportScoreCard extends StatelessWidget {
  const ReportScoreCard({super.key, required this.panels});

  final List<InspectionPanel> panels;

  @override
  Widget build(BuildContext context) {
    final score = reportScoreOf(panels);
    final defective = defectivePanels(panels);
    final scoreColor = score >= 70
        ? context.colors.statusDone
        : score >= 50
        ? context.colors.statusProgress
        : context.colors.statusDefect;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.bg1,
        border: Border.all(color: context.colors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              ScoreRing(percent: score, color: scoreColor),
              Text(
                '$score',
                style: TextStyle(
                  fontFamily: AppTheme.monoFamily,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.72,
                  color: context.colors.text1,
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reportGradeOf(score),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.34,
                    color: context.colors.text1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  defective.isEmpty
                      ? 'Дефектов не отмечено.'
                      : 'Деталей с дефектами: ${defective.length}. '
                            'Подробности ниже.',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.text2,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// .stat-row — деталей, дефектов, фото.
class ReportStats extends StatelessWidget {
  const ReportStats({super.key, required this.panels});

  final List<InspectionPanel> panels;

  @override
  Widget build(BuildContext context) {
    final defective = defectivePanels(panels);
    final photos = panels.fold<int>(0, (a, p) => a + p.photoCount);

    // подпись «детали с дефектами» в две строки — тянем соседей до неё
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Stat('${panels.length}', panelsWord(panels.length)),
          const SizedBox(width: 8),
          _Stat(
            '${defective.length}',
            '${panelsWord(defective.length)} с дефектами',
            color: defective.isEmpty ? null : context.colors.statusDefect,
          ),
          const SizedBox(width: 8),
          _Stat('$photos', 'фото'),
        ],
      ),
    );
  }
}

/// .stat
class _Stat extends StatelessWidget {
  const _Stat(this.value, this.caption, {this.color});

  final String value;
  final String caption;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.bg1,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: AppTheme.monoFamily,
                fontSize: 19,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.38,
                color: color ?? context.colors.text1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: context.colors.text3),
            ),
          ],
        ),
      ),
    );
  }
}

/// .defect-item — превью первого фото детали, название и дефекты.
class ReportDefectItem extends StatelessWidget {
  const ReportDefectItem({super.key, required this.panel, this.onTap});

  final InspectionPanel panel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.colors.bg1,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumb(url: panel.photoUrls.firstOrNull),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      panel.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.colors.text1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      panel.defects.isEmpty
                          ? (panel.condition?.label ?? 'Требует внимания')
                          : panel.defects.join(', '),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.colors.text2,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: context.colors.text3,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// .defect-thumb — фото детали, а без него градиентная заглушка из макета.
class _Thumb extends StatelessWidget {
  const _Thumb({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final placeholder = BoxDecoration(
      borderRadius: BorderRadius.circular(9),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [context.colors.avatarFrom, context.colors.avatarTo],
      ),
    );

    return Container(
      width: 38,
      height: 38,
      clipBehavior: Clip.antiAlias,
      decoration: placeholder,
      child: url == null
          ? null
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
    );
  }
}
