import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../models/order_action.dart';
import '../../models/order_status.dart';
import '../../util/money.dart';
import '../../util/ru_date.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/payment_parts.dart';

/// Подбор до выбора исполнителя — только заказчику: оплата размещения,
/// срок выбора исполнителя и решение после отказа исполнителя. Кнопки — по
/// `Order.actions`, сроки — с сервера (`pickUntil`), на клиенте не считаются.
/// «Отменить заказ» — общая кнопка внизу экрана.
class PlacementSection extends StatelessWidget {
  const PlacementSection({
    super.key,
    required this.order,
    required this.paying,
    required this.reposting,
    required this.onPay,
    required this.onRepost,
  });

  final Order order;

  /// Идёт оплата размещения.
  final bool paying;

  /// Идёт повторное размещение.
  final bool reposting;
  final VoidCallback onPay;
  final VoidCallback onRepost;

  String get _fee =>
      order.placementFee == null ? '' : ' — ${money(order.placementFee!)} ₽';

  @override
  Widget build(BuildContext context) {
    return switch (order.status) {
      OrderStatus.awaitingPlacement => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 22),
          const SectionHead('Оплата размещения'),
          StatusNote(
            icon: Icons.payments_outlined,
            text:
                'Исполнители увидят заказ после оплаты размещения$_fee. '
                'Деньги спишутся, когда вы выберете исполнителя; не выберете '
                'или отмените заказ — вернутся.',
          ),
          if (order.can(OrderAction.payPlacement)) ...[
            const SizedBox(height: 8),
            CtaPrimary(
              label: order.placementFee == null
                  ? 'Оплатить размещение'
                  : 'Оплатить размещение · ${money(order.placementFee!)} ₽',
              loading: paying,
              onPressed: onPay,
            ),
          ],
        ],
      ),
      OrderStatus.awaitingExecutor when order.pickUntil != null => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 22),
          StatusNote(
            icon: Icons.timer_outlined,
            text:
                'Выберите исполнителя из откликов до '
                '${momentLabel(order.pickUntil!)}. Иначе заказ отменится'
                '${order.placementFee == null ? '.' : ', а деньги за размещение вернутся на карту.'}',
          ),
        ],
      ),
      OrderStatus.awaitingDecision
          when order.decisionReason == DecisionReason.executorReleased =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 22),
            const SectionHead('Нужно решение'),
            StatusNote(
              icon: Icons.person_off_outlined,
              text:
                  'Исполнитель отказался от подбора. Разместите заказ заново, '
                  'чтобы выбрать другого исполнителя'
                  '${order.placementFee == null ? '' : ' — второй раз платить не нужно'}, '
                  'или отмените его'
                  '${order.placementFee == null ? '.' : ' — деньги за размещение вернутся на карту.'}',
            ),
            if (order.can(OrderAction.repost)) ...[
              const SizedBox(height: 8),
              CtaPrimary(
                label: 'Разместить заново',
                loading: reposting,
                onPressed: onRepost,
              ),
            ],
          ],
        ),
      _ => const SizedBox.shrink(),
    };
  }
}
