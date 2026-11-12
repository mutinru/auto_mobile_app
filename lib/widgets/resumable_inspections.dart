import 'package:flutter/material.dart';

import '../screens/inspection_overview_screen.dart';
import '../state/inspection_outbox.dart';
import '../state/inspection_store.dart';
import '../theme/app_colors.dart';
import '../util/ru_plural.dart';

/// Карточки «Осмотр без связи» на главной исполнителя (ревью №12): после
/// перезапуска без сети заказы не грузятся, и до осмотра иначе не дойти.
/// Осмотр с несохранёнными изменениями виден всегда, последний открытый —
/// только когда сети нет ([offline]).
class ResumableInspections extends StatelessWidget {
  const ResumableInspections({super.key, required this.offline});

  final bool offline;

  @override
  Widget build(BuildContext context) {
    final registry = InspectionOutboxes.instance;
    if (registry == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: registry,
      builder: (context, _) {
        final items = [
          for (final r in registry.resumable)
            if (r.pendingCount > 0 || (offline && r.lastOpened)) r,
        ];
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
          child: Column(
            children: [
              for (final r in items) _Card(item: r, registry: registry),
            ],
          ),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.item, required this.registry});

  final ResumableInspection item;
  final InspectionOutboxes registry;

  void _open(BuildContext context) {
    final id = item.inspectionId;
    final store = InspectionStore(
      registry.repositoryFor(id),
      outbox: registry.forInspection(id),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        // отчёт отправляется из заказа, когда есть сеть
        builder: (_) => InspectionOverviewScreen(store: store),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = item.pendingCount;
    final subtitle = n > 0
        ? '$n ${plural(n, 'изменение', 'изменения', 'изменений')} ещё не '
              'на сервере'
        : 'Продолжить без сети — изменения сохранятся позже';
    return Material(
      color: c.bg1,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined, size: 20, color: c.text2),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Осмотр · ${item.title ?? '№${item.inspectionId}'}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.text1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: c.text3),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: c.text3),
            ],
          ),
        ),
      ),
    );
  }
}
