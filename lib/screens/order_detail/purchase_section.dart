import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../models/order_action.dart';
import '../../models/order_car.dart';
import '../../models/order_status.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/payment_parts.dart';

/// Сообщение исполнителя о покупке (ревью №16), пока подбор идёт — главное
/// действие, пока ждёт ответа. Заказчику — вопрос с «Да»/«Нет», исполнителю
/// — «ждём подтверждения». Кнопки — по `Order.actions`.
class PurchaseReportBlock extends StatelessWidget {
  const PurchaseReportBlock({
    super.key,
    required this.order,
    required this.viewerIsCustomer,
    required this.completing,
    required this.busy,
    required this.onConfirm,
    required this.onDecline,
  });

  final Order order;
  final bool viewerIsCustomer;

  /// Идёт покупка («Да, купил» — со спиннером).
  final bool completing;

  /// Идёт другое действие с покупкой — кнопки гаснут.
  final bool busy;

  /// «Да, купил» — покупка машины из сообщения.
  final void Function(int carId) onConfirm;

  /// «Нет, не покупал».
  final void Function(OrderCar? car) onDecline;

  @override
  Widget build(BuildContext context) {
    final report = order.purchaseReport;
    if (report == null ||
        order.isInspection ||
        (order.status != OrderStatus.sourcing &&
            order.status != OrderStatus.inspecting)) {
      return const SizedBox.shrink();
    }
    final car = order.cars.where((c) => c.id == report.carId).firstOrNull;
    final title = car?.title ?? 'машины';
    if (!viewerIsCustomer) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 22),
          StatusNote(text: 'Ждём подтверждения заказчика: $title.'),
        ],
      );
    }
    final executor = order.executor?.name ?? 'Подборщик';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        StatusNote(
          icon: Icons.key_outlined,
          text:
              '$executor отметил покупку $title. Подтвердите — и сможете '
              'оценить подборщика.',
        ),
        const SizedBox(height: 10),
        if (order.can(OrderAction.complete))
          CtaPrimary(
            label: 'Да, купил',
            icon: Icons.check,
            loading: completing,
            onPressed: busy ? null : () => onConfirm(report.carId),
          ),
        if (order.can(OrderAction.declinePurchaseReport))
          CtaGhost(
            label: 'Нет, не покупал',
            onPressed: busy || completing ? null : () => onDecline(car),
          ),
      ],
    );
  }
}

/// Покупка у заказчика (ревью №16): «Зафиксировать покупку», а при ждущем
/// сообщении исполнителя — «Купил другую машину»; сутки после закрытия —
/// «Изменить покупку» (окно с сервера).
class PurchaseActions extends StatelessWidget {
  const PurchaseActions({
    super.key,
    required this.order,
    required this.viewerIsCustomer,
    required this.completing,
    required this.busy,
    required this.onComplete,
    required this.onChange,
  });

  final Order order;
  final bool viewerIsCustomer;
  final bool completing;
  final bool busy;

  /// Выбрать купленную машину листом.
  final VoidCallback onComplete;

  /// Выбрать другую купленную машину.
  final VoidCallback onChange;

  /// Есть из чего выбрать другую купленную: кандидатов с осмотром больше
  /// одного (без осмотра покупку не отметить — сервер ответит 422).
  bool get _hasPurchaseChoice =>
      order.cars.where((c) => c.inspectionId != null).length > 1;

  @override
  Widget build(BuildContext context) {
    final canComplete = viewerIsCustomer && order.can(OrderAction.complete);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // при ждущем сообщении исполнителя главная кнопка — «Да, купил»
        // выше; другую машину заказчик всё равно может отметить сам
        if (canComplete)
          if (order.purchaseReport == null) ...[
            const SizedBox(height: 14),
            CtaPrimary(
              label: 'Зафиксировать покупку',
              icon: Icons.check,
              loading: completing,
              onPressed: onComplete,
            ),
          ] else if (_hasPurchaseChoice)
            CtaGhost(
              label: 'Купил другую машину',
              onPressed: completing || busy ? null : onComplete,
            ),
        if (viewerIsCustomer && order.can(OrderAction.changePurchase)) ...[
          const SizedBox(height: 14),
          CtaGhost(
            label: 'Изменить покупку',
            onPressed: busy ? null : onChange,
          ),
        ],
      ],
    );
  }
}
