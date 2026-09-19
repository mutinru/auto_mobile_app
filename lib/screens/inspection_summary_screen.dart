import 'package:flutter/material.dart';

import '../models/inspection_panel.dart';
import '../models/panel_condition.dart';
import '../models/panel_status.dart';
import '../state/inspection_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/score_ring.dart';

/// Экран 09 макета — «сводка и отчёт».
class InspectionSummaryScreen extends StatelessWidget {
  const InspectionSummaryScreen({super.key, required this.store});

  final InspectionStore store;

  /// Балл считаем из оценок деталей: у макета в этом месте «78», но
  /// откуда он берётся, дизайн не описывает. Веса подобраны так, чтобы
  /// A/B давали «хорошо», C тянул вниз, D — сильно вниз.
  static int scoreOf(List<InspectionPanel> panels) {
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

  static String gradeOf(int score) {
    if (score >= 85) return 'Отличное состояние';
    if (score >= 70) return 'Хорошее состояние';
    if (score >= 50) return 'Удовлетворительное';
    return 'Требует ремонта';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final panels = store.panels;
        final score = scoreOf(panels);
        final defective = panels
            .where((p) => p.status == PanelStatus.defect || p.defects.isNotEmpty)
            .toList();
        final photos = panels.fold<int>(0, (a, p) => a + p.photoCount);

        final scoreColor = score >= 70
            ? AppColors.statusDone
            : score >= 50
                ? AppColors.statusProgress
                : AppColors.statusDefect;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                DetailHead(
                  title: 'Сводка',
                  eyebrow: 'осмотр завершён',
                  onBack: () => Navigator.of(context).pop(),
                  trailing: DetailPos('${store.evaluatedCount}/${store.totalCount}'),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 18),
                    children: [
                      // .score-card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.bg1,
                          border: Border.all(color: AppColors.line),
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
                                  style: const TextStyle(
                                    fontFamily: AppTheme.monoFamily,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.72,
                                    color: AppColors.text1,
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
                                    gradeOf(score),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.34,
                                      color: AppColors.text1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    defective.isEmpty
                                        ? 'Дефектов не отмечено.'
                                        : 'Отмечено дефектов: ${defective.length}. '
                                            'Подробности ниже.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.text2,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // .stat-row
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _Stat('${panels.length}', 'деталей'),
                          const SizedBox(width: 8),
                          _Stat(
                            '${defective.length}',
                            'дефекта',
                            color: defective.isEmpty ? null : AppColors.statusDefect,
                          ),
                          const SizedBox(width: 8),
                          _Stat('$photos', 'фото'),
                        ],
                      ),

                      const SizedBox(height: 22),
                      const SectionHead('Найденные дефекты'),
                      if (defective.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Дефекты не отмечены',
                            style: TextStyle(fontSize: 12, color: AppColors.text3),
                          ),
                        )
                      else
                        for (final p in defective) _DefectItem(panel: p),

                      const SizedBox(height: 22),
                      const SectionHead('Подпись клиента', extra: 'обязательно'),
                      // .sign-pad
                      Container(
                        height: 84,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.bg1,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.line,
                            width: 1.5,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: const Text(
                          'Подпись пока не поддерживается',
                          style: TextStyle(fontSize: 11.5, color: AppColors.text3),
                        ),
                      ),
                    ],
                  ),
                ),
                BottomCta(
                  children: [
                    CtaPrimary(
                      label: 'Отправить отчёт клиенту',
                      icon: Icons.send,
                      onPressed: store.remainingCount == 0 ? () {} : null,
                    ),
                    CtaGhost(label: 'Скачать PDF', onPressed: () {}),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
          color: AppColors.bg1,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: AppTheme.monoFamily,
                fontSize: 19,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.38,
                color: color ?? AppColors.text1,
              ),
            ),
            const SizedBox(height: 3),
            Text(caption, style: const TextStyle(fontSize: 10, color: AppColors.text3)),
          ],
        ),
      ),
    );
  }
}

/// .defect-item
class _DefectItem extends StatelessWidget {
  const _DefectItem({required this.panel});

  final InspectionPanel panel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // .defect-thumb — превью первого фото детали; самих файлов
          // в списке нет, поэтому пока градиентная заглушка из макета
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF5A6470), Color(0xFF2C3138)],
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  panel.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  panel.defects.isEmpty
                      ? (panel.condition?.label ?? 'Требует внимания')
                      : panel.defects.join(', '),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.text2,
                    height: 1.4,
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
