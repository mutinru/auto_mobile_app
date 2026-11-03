import 'package:flutter/material.dart';

import '../models/vin_report.dart';
import '../screens/vin_report_screen.dart' show vinReportLine;
import '../theme/app_colors.dart';
import '../util/ru_plural.dart';
import 'app_ui.dart';

/// Предложение под полем VIN в форме осмотра: по этой машине уже есть
/// готовые отчёты. Всё — из ответа сервера (`VinReportCheck`), клиент
/// ничего не считает. Вердикта до покупки нет — только когда, где и
/// с каким пробегом осматривали.
class VinReportOffer extends StatelessWidget {
  const VinReportOffer({
    super.key,
    required this.check,
    required this.onBuy,
    required this.onOpen,
    this.buying = false,
  });

  final VinReportCheck check;
  final VoidCallback onBuy;

  /// Пакет уже куплен — открыть его.
  final VoidCallback onOpen;
  final bool buying;

  @override
  Widget build(BuildContext context) {
    final n = check.items.length;
    final last = check.items.first;
    final bought = check.purchaseId != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      decoration: BoxDecoration(
        color: context.colors.statusDone.withValues(alpha: 0.08),
        border: Border.all(
          color: context.colors.statusDone.withValues(alpha: 0.35),
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.fact_check_outlined,
                size: 17,
                color: context.colors.doneText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Эту машину уже осматривали '
                  '${counted(n, 'раз', 'раза', 'раз')}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.colors.text1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${n > 1 ? 'Последний — ' : ''}${vinReportLine(last)}',
            style: TextStyle(fontSize: 12, color: context.colors.text2),
          ),
          const SizedBox(height: 10),
          CtaPrimary(
            label: bought
                ? 'Открыть отчёт'
                : 'Купить за ${money(check.price)} ₽',
            loading: buying,
            onPressed: bought ? onOpen : onBuy,
          ),
          if (!bought) ...[
            const SizedBox(height: 6),
            Text(
              'Вердикт, оценка каждой детали, дефекты и фото. '
              'Или закажите новый осмотр ниже.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: context.colors.text3),
            ),
          ],
        ],
      ),
    );
  }
}

/// Подтверждение покупки. true — нажали «Оплатить».
Future<bool> confirmVinReportPurchase(
  BuildContext context,
  VinReportCheck check,
) async {
  final n = check.items.length;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: context.colors.bg0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Отчёт по VIN ··· ${check.vin.substring(check.vin.length - 6)}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: context.colors.text1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${counted(n, 'осмотр', 'осмотра', 'осмотров')} одним '
              'пакетом: вердикт, оценка деталей, дефекты и фото. Данных '
              'продавца и голосовых заметок в отчёте нет.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: context.colors.text2,
              ),
            ),
            const SizedBox(height: 16),
            CtaPrimary(
              label: 'Оплатить ${money(check.price)} ₽',
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    ),
  );
  return ok ?? false;
}
