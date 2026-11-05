import 'package:flutter/material.dart';

import '../models/inspection_panel.dart';
import '../screens/panel_detail_screen.dart';
import '../state/inspection_store.dart';
import '../theme/app_colors.dart';
import 'app_ui.dart';

/// Шторка «Осталось исправить»: что мешает отправить отчёт.
///
/// Раньше «Завершить осмотр» молча уводил на схему, а её кнопка — в первую
/// недоделанную деталь, и было непонятно, что произошло. Теперь исполнитель
/// видит список с причинами. Деталь из него открывается в режиме исправления:
/// «Готово» возвращает сюда, а не ведёт по всем деталям подряд.
///
/// Возвращает true, если всё исправлено и нажато «Сформировать отчёт».
Future<bool> showInspectionProblems(
  BuildContext context,
  InspectionStore store,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: context.colors.bg0,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _ProblemsSheet(store: store),
  );
  return result ?? false;
}

class _ProblemsSheet extends StatelessWidget {
  const _ProblemsSheet({required this.store});

  final InspectionStore store;

  void _open(BuildContext context, InspectionPanel panel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PanelDetailScreen(store: store, panelId: panel.id, fixMode: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final problems = store.problems;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.8,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    problems.isEmpty
                        ? 'Всё заполнено'
                        : 'Осталось исправить · ${problems.length}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: context.colors.text1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    problems.isEmpty
                        ? 'Можно формировать отчёт'
                        : 'Без этого отчёт не отправить — нажмите на пункт',
                    style: TextStyle(fontSize: 12, color: context.colors.text3),
                  ),
                  const SizedBox(height: 12),
                  if (problems.isNotEmpty)
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final p in problems)
                            _ProblemRow(
                              panel: p,
                              onTap: () => _open(context, p),
                            ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: NextStepButton(
                        caption: 'Осмотр завершён',
                        title: 'Сформировать отчёт',
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProblemRow extends StatelessWidget {
  const _ProblemRow({required this.panel, required this.onTap});

  final InspectionPanel panel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
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
                    const SizedBox(height: 2),
                    Text(
                      panel.missingLabel ?? '',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.colors.progressText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: context.colors.text3),
            ],
          ),
        ),
      ),
    );
  }
}
