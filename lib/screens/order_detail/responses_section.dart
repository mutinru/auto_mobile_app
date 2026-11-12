import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../models/order_action.dart';
import '../../models/order_response.dart';
import '../../models/order_response_status.dart';
import '../../models/order_status.dart';
import '../../models/user_summary.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/phone_contact.dart';
import '../../widgets/response_card.dart';

/// Отклики подбора у заказчика (ревью №16): выбранный — первым, за ним
/// ждущие решения, решённые — в конце. «Выбрать» — по
/// `actions.accept_response`.
class ResponsesSection extends StatelessWidget {
  const ResponsesSection({
    super.key,
    required this.order,
    required this.onAccept,
    required this.onShowReviews,
  });

  final Order order;
  final void Function(int responseId) onAccept;
  final void Function(UserSummary executor) onShowReviews;

  @override
  Widget build(BuildContext context) {
    final responses = order.responses;
    if (responses.isEmpty) return const SizedBox.shrink();
    final ordered = <OrderResponse>[
      ...responses.where((r) => r.status == OrderResponseStatus.accepted),
      ...responses.where((r) => r.status == OrderResponseStatus.pending),
      ...responses.where((r) => !r.status.isActive),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        SectionHead('Отклики', extra: '${responses.length}'),
        if (order.status == OrderStatus.awaitingExecutor &&
            responses.any((r) => r.status == OrderResponseStatus.pending))
          const PhoneExchangeNote(
            'Когда вы выберете исполнителя, вы увидите телефоны друг '
            'друга — сможете созвониться напрямую.',
          ),
        for (final r in ordered)
          ResponseCard(
            response: r,
            askingPrice: order.askingPrice,
            onAccept:
                r.status == OrderResponseStatus.pending &&
                    order.can(OrderAction.acceptResponse)
                ? () => onAccept(r.id)
                : null,
            onShowReviews: () => onShowReviews(r.executor),
          ),
      ],
    );
  }
}
