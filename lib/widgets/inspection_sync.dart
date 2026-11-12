import 'dart:async';

import 'package:flutter/material.dart';

import '../state/inspection_store.dart';
import '../theme/app_colors.dart';
import '../util/ru_plural.dart';

/// Плашка синхронизации осмотра (ревью №12): что ещё не на сервере и почему.
/// Всё сохранено — плашки нет.
class InspectionSyncBanner extends StatelessWidget {
  const InspectionSyncBanner({super.key, required this.store});

  final InspectionStore store;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = store.pendingCount;
    final changes = '$n ${plural(n, 'изменение', 'изменения', 'изменений')}';
    final (IconData icon, String text)? content = switch (n) {
      0 when store.isOffline => (
        Icons.cloud_off_outlined,
        'Без сети — показана сохранённая копия. Нажмите, чтобы обновить',
      ),
      0 => null,
      _ when store.isWaitingForNetwork => (
        Icons.cloud_off_outlined,
        'Нет связи — $changes сохранятся, когда появится сеть',
      ),
      _ => (Icons.cloud_upload_outlined, 'Сохраняем $changes…'),
    };
    if (content == null) return const SizedBox.shrink();
    final banner = Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: c.bg1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Icon(content.$1, size: 16, color: c.text2),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              content.$2,
              style: TextStyle(fontSize: 12.5, color: c.text2),
            ),
          ),
        ],
      ),
    );
    if (n > 0) return banner;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: store.refresh,
      child: banner,
    );
  }
}

/// Отказы сервера действиям очереди — снекбаром, только на верхнем экране
/// (обзор и деталь подписаны оба).
StreamSubscription<String> listenRejections(
  State state,
  InspectionStore store,
) => store.rejections.listen((message) {
  if (!state.mounted) return;
  final context = state.context;
  if (!context.mounted) return;
  if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
});
