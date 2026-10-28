import 'package:flutter/material.dart';

import '../models/order_response.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_ui.dart';

/// .resp — отклик исполнителя на заказ-осмотр (order-types.html, кадр 04).
/// Цена заказчика — точка отсчёта: рядом с ценой отклика видна разница
/// с ней. Рейтинг «★ 4.9 · 212 осмотров» из макета не рисуем — рейтинга
/// в домене нет, выдумывать не будем.
class ResponseCard extends StatelessWidget {
  const ResponseCard({
    super.key,
    required this.response,
    required this.askingPrice,
    this.onAccept,
  });

  final OrderResponse response;
  final int? askingPrice;

  /// null — заказчик уже выбрал исполнителя или экран смотрит не он.
  final VoidCallback? onAccept;

  /// (подпись, цвет) для .resp-price-delta.
  (String, Color)? _delta(AppColors c) {
    if (askingPrice == null) return null;
    final diff = response.proposedPrice - askingPrice!;
    if (diff == 0) return ('ваша цена', c.text3);
    return diff < 0
        ? ('−${money(-diff)} ₽', c.statusDone)
        : ('+${money(diff)} ₽', c.statusProgress);
  }

  @override
  Widget build(BuildContext context) {
    final delta = _delta(context.colors);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.bg1,
        border: Border.all(color: context.colors.line),
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
                child: Text(
                  response.executor.name,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.colors.text1,
                  ),
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
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
