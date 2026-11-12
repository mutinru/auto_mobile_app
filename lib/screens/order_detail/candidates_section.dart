import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/inspection_outcome.dart';
import '../../models/inspection_verdict.dart';
import '../../models/order.dart';
import '../../models/order_action.dart';
import '../../models/order_car.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../util/ru_date.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/phone_contact.dart';
import '../../widgets/phone_input.dart';

/// Кандидаты подбора (ревью №16) — то, ради чего заказчик открывает подбор:
/// сразу под исполнителем, до отзыва и откликов. Тап открывает осмотр,
/// подборщику — строка телефона продавца.
class CandidatesSection extends StatelessWidget {
  const CandidatesSection({
    super.key,
    required this.order,
    required this.showSellerPhone,
    this.onOpen,
    this.onEditSellerPhone,
  });

  final Order order;

  /// Телефон продавца — заметка подборщика; заказчику сервер его не отдаёт,
  /// но и показывать незачем.
  final bool showSellerPhone;

  /// Открыть осмотр кандидата; null — открыть неоткуда.
  final void Function(OrderCar car)? onOpen;

  /// Правка телефона продавца — по `actions.edit_seller_phone`.
  final void Function(OrderCar car)? onEditSellerPhone;

  @override
  Widget build(BuildContext context) {
    if (order.cars.isEmpty) return const SizedBox.shrink();
    final canEdit = order.can(OrderAction.editSellerPhone);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        SectionHead('Кандидаты', extra: '${order.cars.length}'),
        for (final car in order.cars)
          _CandidateCard(
            car: car,
            onTap: car.inspectionId != null && onOpen != null
                ? () => onOpen!(car)
                : null,
            showSellerPhone: showSellerPhone,
            onEditSellerPhone: canEdit && onEditSellerPhone != null
                ? () => onEditSellerPhone!(car)
                : null,
          ),
      ],
    );
  }
}

/// Кандидат подбора: машина, комментарий к вердикту и плашка — идёт
/// осмотр, исход покупки или вердикт. Купленная — в зелёной рамке, как
/// выбранный отклик: в длинном списке её видно сразу. Тап открывает осмотр.
class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.car,
    this.onTap,
    this.showSellerPhone = false,
    this.onEditSellerPhone,
  });

  final OrderCar car;
  final VoidCallback? onTap;

  /// Подборщику — строка телефона продавца (или «Добавить»).
  final bool showSellerPhone;

  /// Правка номера; null — заказ отменён, только показ.
  final VoidCallback? onEditSellerPhone;

  /// Цвет плашки: идущий осмотр — синий, покупка — зелёный, дальше вердикт
  /// (и у некупленных после покупки); «осмотрена» и «осмотр не начат» —
  /// нейтральные.
  Color? _pillColor(AppColors c) {
    if (car.inspectionStatus == 'in_progress') return c.statusInfo;
    if (car.inspectionOutcome == InspectionOutcome.purchased) {
      return c.statusDone;
    }
    return car.verdict?.color(c);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final comment = car.verdictComment;
    final bought = car.inspectionOutcome == InspectionOutcome.purchased;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: bought ? Color.alphaBlend(c.buySoft, c.bg1) : c.bg1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: bought
              ? BorderSide(color: c.buyEdge, width: 1.5)
              : BorderSide(color: c.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            car.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.text1,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Pill(car.inspectionLabel, color: _pillColor(c)),
                          // осмотр из библиотеки сделан раньше — когда
                          if (car.fromLibrary &&
                              car.inspectionCompletedAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: Text(
                                inspectedAgo(car.inspectionCompletedAt!),
                                style: TextStyle(fontSize: 12, color: c.text2),
                              ),
                            ),
                          if (comment != null && comment.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: Text(
                                comment,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: c.text2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right, size: 20, color: c.text2),
                    ],
                  ],
                ),
                if (showSellerPhone)
                  _SellerPhoneLine(
                    phone: car.sellerPhone,
                    onEdit: onEditSellerPhone,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Телефон продавца в карточке кандидата — только подборщику: номер с
/// «Скопировать» и «Позвонить», тап по номеру — правка. Номера нет —
/// «Добавить телефон продавца».
class _SellerPhoneLine extends StatelessWidget {
  const _SellerPhoneLine({required this.phone, this.onEdit});

  final String? phone;
  final VoidCallback? onEdit;

  void _copy(BuildContext context, String phone) {
    Clipboard.setData(ClipboardData(text: formatPhone(phone)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Номер продавца скопирован')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final phone = this.phone;
    if (phone == null) {
      if (onEdit == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: TextButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Телефон продавца · только для вас'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 11),
        Container(height: 1, color: c.line),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Продавец · только для вас',
                        style: TextStyle(fontSize: 11.5, color: c.text2),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              formatPhone(phone),
                              style: TextStyle(
                                fontFamily: AppTheme.monoFamily,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: c.text1,
                              ),
                            ),
                          ),
                          if (onEdit != null) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.edit_outlined, size: 14, color: c.text2),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Скопировать',
              onPressed: () => _copy(context, phone),
              icon: Icon(Icons.copy_rounded, size: 19, color: c.text1),
            ),
            IconButton.filled(
              tooltip: 'Позвонить',
              onPressed: () => callPhone(context, phone),
              style: IconButton.styleFrom(
                backgroundColor: c.modeBuy,
                foregroundColor: c.modeBuyInk,
              ),
              icon: const Icon(Icons.call, size: 19),
            ),
          ],
        ),
      ],
    );
  }
}
