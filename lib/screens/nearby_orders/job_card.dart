import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../util/geo.dart';
import '../../util/money.dart';
import '../../util/ru_date.dart';
import '../../util/ru_plural.dart';
import '../../widgets/app_ui.dart';

/// .card.job — свободный заказ с гонораром и кнопкой отклика.
class JobCard extends StatelessWidget {
  const JobCard({
    super.key,
    required this.order,
    required this.canRespond,
    required this.onRespond,
    this.here,
  });

  final Order order;
  final (double, double)? here;
  final bool canRespond;
  final VoidCallback onRespond;

  /// У осмотра цену назначает заказчик — показываем её. У подбора её в
  /// API нет: `price` появляется только при принятии отклика, поэтому
  /// там остаётся свой отклик или «предлагаете вы». Чужие цены сервер
  /// исполнителю не отдаёт — минимум по ним не посчитать.
  (String, String) get _pay {
    if (order.price != null) {
      return ('Гонорар за заказ', '${money(order.price!)} ₽');
    }
    if (order.askingPrice != null) {
      return ('Цена заказчика', '${money(order.askingPrice!)} ₽');
    }
    if (order.hasViewerResponse) {
      return ('Ваш отклик', '${money(order.viewerResponse!.proposedPrice)} ₽');
    }
    return ('Гонорар за заказ', 'предлагаете вы');
  }

  String get _place {
    final (lat, lon, at) = (order.lat, order.lon, here);
    return [
      if (order.cities.isNotEmpty) order.cities.first,
      if (lat != null && lon != null && at != null)
        distanceLabel(distanceKm(at.$1, at.$2, lat, lon)),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final (payCaption, payValue) = _pay;
    // у осмотра вместо бюджета — когда и куда ехать
    final meta = order.isInspection
        ? [
            whenLabel(order.inspectOn, order.timeSlot, order.inspectTime),
            counted(order.responsesCount, 'отклик', 'отклика', 'откликов'),
          ].join(' · ')
        : [
            ?budgetShort(order.budgetMin, order.budgetMax),
            counted(order.responsesCount, 'отклик', 'отклика', 'откликов'),
          ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.modeWork.withValues(alpha: 0.045),
        border: Border.all(
          color: context.colors.modeWork.withValues(alpha: 0.35),
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pill('свободен', color: context.colors.modeWork),
              const SizedBox(width: 8),
              // «Химки · 8 км» из макета; у подбора точки нет — только город.
              // Улицу сервер до выбора исполнителя не отдаёт.
              Expanded(
                child: Text(
                  _place,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.sectionExtra,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(order.carTitle, style: context.text.orderCar),
          const SizedBox(height: 5),
          Text(meta, style: context.text.orderMeta),

          // .pay
          Container(
            margin: const EdgeInsets.only(top: 11),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.colors.bg0,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    payCaption,
                    style: TextStyle(fontSize: 11, color: context.colors.text2),
                  ),
                ),
                Text(
                  payValue,
                  style: TextStyle(
                    fontFamily: AppTheme.monoFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                    color: context.colors.progressText,
                  ),
                ),
              ],
            ),
          ),

          // .take — в макете первая кнопка заливная, остальные ghost; это
          // приём статичной картинки, в живом списке заказы равноправны
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canRespond && order.canViewerRespond
                  ? onRespond
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.modeWork,
                foregroundColor: context.colors.modeWorkInk,
                disabledBackgroundColor: context.colors.bg3,
                disabledForegroundColor: context.colors.text3,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                elevation: 0,
              ),
              child: Text(
                order.respondLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
