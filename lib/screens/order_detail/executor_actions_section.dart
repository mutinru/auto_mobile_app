import 'package:flutter/material.dart';

import '../../models/library_inspection.dart';
import '../../models/order.dart';
import '../../widgets/app_ui.dart';

/// Действия исполнителя подбора (ревью №16): новый кандидат, свой готовый
/// осмотр, «Заказчик купил машину», отказ. Каждая кнопка — по правилу сервера
/// (`actions` / `canReportPurchase` / `canRelease`).
class ExecutorActionsSection extends StatelessWidget {
  const ExecutorActionsSection({
    super.key,
    required this.order,
    required this.viewerIsCustomer,
    required this.canAddCandidates,
    required this.library,
    required this.attaching,
    required this.purchaseBusy,
    required this.releasing,
    required this.onStartInspection,
    required this.onAttachFromLibrary,
    required this.onReportPurchase,
    required this.onRelease,
  });

  final Order order;
  final bool viewerIsCustomer;

  /// `actions.add_candidate` — назначенный исполнитель идущего подбора.
  final bool canAddCandidates;

  /// Свои готовые осмотры; кнопка — только если есть что добавить.
  final InspectionLibraryPage? library;
  final bool attaching;
  final bool purchaseBusy;
  final bool releasing;

  final VoidCallback onStartInspection;
  final VoidCallback onAttachFromLibrary;
  final VoidCallback onReportPurchase;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    final items = library?.items ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Заводить кандидата и стартовать осмотр может только назначенный
        // исполнитель — у заказчика этот вызов вернёт 403; в закрытый подбор
        // нового кандидата не завести (422), начатые — дозавершаются.
        if (canAddCandidates) ...[
          const SizedBox(height: 14),
          CtaPrimary(
            label: 'Осмотреть новый вариант',
            icon: Icons.add,
            onPressed: onStartInspection,
          ),
          if (items.isNotEmpty)
            CtaGhost(
              label: 'Из моих осмотров · ${items.length}',
              onPressed: attaching ? null : onAttachFromLibrary,
            ),
        ],
        // заказчик купил, но не отметил — сообщает подборщик (правило с сервера)
        if (!viewerIsCustomer && order.canReportPurchase)
          CtaGhost(
            label: 'Заказчик купил машину',
            onPressed: purchaseBusy ? null : onReportPurchase,
          ),
        // выход из подбора — только по правилу с сервера (can_release)
        if (!viewerIsCustomer && order.canRelease)
          CtaGhost(
            label: 'Отказаться от подбора',
            onPressed: releasing ? null : onRelease,
          ),
      ],
    );
  }
}
