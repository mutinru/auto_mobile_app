import 'package:flutter/material.dart';

import '../models/order_response.dart';
import '../models/order_response_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_ui.dart';
import 'executor_stats.dart';

/// .resp — отклик исполнителя на заказ (order-types.html, кадр 04).
/// Цена заказчика — точка отсчёта: рядом с ценой отклика видна разница
/// с ней. Под именем — .resp-stats: рейтинг и число отзывов исполнителя.
///
/// Решённый отклик несёт плашку статуса у имени; выбранный ещё и в
/// зелёной рамке — в списке откликов подбора его видно сразу.
class ResponseCard extends StatelessWidget {
  const ResponseCard({
    super.key,
    required this.response,
    required this.askingPrice,
    this.onAccept,
    this.onShowReviews,
  });

  final OrderResponse response;
  final int? askingPrice;

  /// null — заказчик уже выбрал исполнителя или экран смотрит не он.
  final VoidCallback? onAccept;

  /// Открыть отзывы об исполнителе по тапу на рейтинг.
  final VoidCallback? onShowReviews;

  /// (подпись, цвет) для .resp-price-delta.
  (String, Color)? _delta(AppColors c) {
    if (askingPrice == null) return null;
    final diff = response.proposedPrice - askingPrice!;
    if (diff == 0) return ('ваша цена', c.text3);
    return diff < 0
        ? ('−${money(-diff)} ₽', c.doneText)
        : ('+${money(diff)} ₽', c.progressText);
  }

  /// Плашка у имени: null — отклик ждёт решения.
  Widget? _statusPill(AppColors c) => switch (response.status) {
    OrderResponseStatus.pending => null,
    OrderResponseStatus.accepted => Pill('Выбран', color: c.statusDone),
    final status => Pill(status.label),
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final delta = _delta(c);
    final chosen = response.status == OrderResponseStatus.accepted;
    final pill = _statusPill(c);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: chosen ? Color.alphaBlend(c.buySoft, c.bg1) : c.bg1,
        border: Border.all(
          color: chosen ? c.buyEdge : c.line,
          width: chosen ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(initialsOf(response.executor.name), size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            response.executor.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: c.text1,
                            ),
                          ),
                        ),
                        if (pill != null) ...[const SizedBox(width: 8), pill],
                      ],
                    ),
                    const SizedBox(height: 2),
                    ExecutorStats(
                      user: response.executor,
                      onTap: onShowReviews,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${money(response.proposedPrice)} ₽',
                    style: TextStyle(
                      fontFamily: AppTheme.monoFamily,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: context.colors.text1,
                    ),
                  ),
                  if (delta != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      delta.$1,
                      style: TextStyle(
                        fontFamily: AppTheme.monoFamily,
                        fontSize: 10.5,
                        color: delta.$2,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (response.message != null && response.message!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Text(
                response.message!,
                style: TextStyle(
                  fontSize: 11.5,
                  color: context.colors.text2,
                  height: 1.4,
                ),
              ),
            ),
          if (onAccept != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.modeBuy,
                    foregroundColor: context.colors.modeBuyInk,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Выбрать',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
