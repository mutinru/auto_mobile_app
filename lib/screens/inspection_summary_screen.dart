import 'package:flutter/material.dart';

import '../state/inspection_store.dart';
import '../theme/app_colors.dart';
import '../widgets/app_ui.dart';
import '../widgets/inspection_report_parts.dart';

/// Экран 09 макета — «сводка и отчёт».
class InspectionSummaryScreen extends StatelessWidget {
  const InspectionSummaryScreen({
    super.key,
    required this.store,
    this.onSendReport,
  });

  final InspectionStore store;

  /// «Отправить отчёт клиенту». У разового осмотра ведёт к вердикту
  /// ([AssignedInspectionScreen]); у подбора отправки пока нет — кнопка
  /// остаётся заглушкой.
  final VoidCallback? onSendReport;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final panels = store.panels;
        final defective = defectivePanels(panels);

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                DetailHead(
                  title: 'Сводка',
                  eyebrow: 'осмотр завершён',
                  onBack: () => Navigator.of(context).pop(),
                  trailing: DetailPos(
                    '${store.evaluatedCount}/${store.totalCount}',
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 18),
                    children: [
                      ReportScoreCard(panels: panels),
                      const SizedBox(height: 12),
                      ReportStats(panels: panels),

                      const SizedBox(height: 22),
                      const SectionHead('Найденные дефекты'),
                      if (defective.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Дефекты не отмечены',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.text3,
                            ),
                          ),
                        )
                      else
                        for (final p in defective) ReportDefectItem(panel: p),

                      const SizedBox(height: 22),
                      const SectionHead(
                        'Подпись клиента',
                        extra: 'обязательно',
                      ),
                      // .sign-pad
                      Container(
                        height: 84,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.colors.bg1,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: context.colors.line,
                            width: 1.5,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Text(
                          'Подпись пока не поддерживается',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.colors.text3,
                          ),
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
                      onPressed: store.remainingCount == 0
                          ? (onSendReport ?? () {})
                          : null,
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
