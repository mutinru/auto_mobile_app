import 'package:flutter/material.dart';

import '../models/inspection_panel.dart';
import '../state/inspection_store.dart';
import '../theme/app_colors.dart';
import '../widgets/app_ui.dart';
import '../widgets/inspection_report_parts.dart';
import 'panel_detail_screen.dart';

/// Экран 09 макета — «сводка и отчёт».
class InspectionSummaryScreen extends StatelessWidget {
  const InspectionSummaryScreen({
    super.key,
    required this.store,
    this.onSendReport,
    this.sendLabel = 'Отправить отчёт клиенту',
  });

  /// У подбора — «Завершить осмотр»: итог по кандидату, заказ не закрывается.
  final String sendLabel;

  final InspectionStore store;

  /// Главная кнопка сводки ведёт к вердикту: у разового осмотра —
  /// [AssignedInspectionScreen], у подбора — итог кандидата в
  /// [OrderDetailScreen]. Без колбэка (только просмотр) кнопка ничего не делает.
  final VoidCallback? onSendReport;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final panels = store.panels;
        final defective = defectivePanels(panels);
        final incomplete = store.readOnly
            ? const <InspectionPanel>[]
            : store.incompletePanels;

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
                      if (incomplete.isNotEmpty) ...[
                        SectionHead(
                          'Не хватает',
                          extra: '${incomplete.length}',
                        ),
                        for (final p in incomplete)
                          _IncompleteItem(
                            panel: p,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                // «Готово» вернёт сюда, а не поведёт по всем
                                // деталям подряд
                                builder: (_) => PanelDetailScreen(
                                  store: store,
                                  panelId: p.id,
                                  fixMode: true,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 22),
                      ],
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
                    ],
                  ),
                ),
                // без onSendReport отправлять нечего (осмотр только смотрят) —
                // нижней панели нет, а не пустая кнопка. «Скачать PDF» и
                // подпись клиента из макета 09 не перенесены (QA №9)
                if (onSendReport case final send?)
                  BottomCta(
                    children: [
                      CtaPrimary(
                        label: sendLabel,
                        icon: Icons.send,
                        // то же правило проверит сервер при отправке
                        onPressed: store.isReportComplete ? send : null,
                      ),
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

/// Деталь, которой для отчёта не хватает фото или дефекта; тап — к ней.
class _IncompleteItem extends StatelessWidget {
  const _IncompleteItem({required this.panel, required this.onTap});

  final InspectionPanel panel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.bg1,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              size: 16,
              color: context.colors.progressText,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                panel.name,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: context.colors.text1,
                ),
              ),
            ),
            Text(
              panel.missingLabel ?? '',
              style: TextStyle(
                fontSize: 11,
                color: context.colors.progressText,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 14, color: context.colors.text3),
          ],
        ),
      ),
    );
  }
}
