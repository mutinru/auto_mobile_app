import 'package:flutter/material.dart';

import '../models/inspection_verdict.dart';
import '../models/library_inspection.dart';
import '../theme/app_colors.dart';
import '../util/ru_date.dart';
import 'app_sheet.dart';
import 'app_ui.dart';
import 'confirm_sheet.dart';

/// Выбор своего готового осмотра для подбора: лист со списком, затем
/// подтверждение «машина ещё продаётся» — осмотру до [InspectionLibraryPage.days]
/// дней, объявление могли снять. Возвращает выбранный осмотр, только если
/// исполнитель подтвердил; иначе null.
Future<LibraryInspection?> pickFromLibrary(
  BuildContext context,
  InspectionLibraryPage page,
) async {
  final picked = await showAppSheet<LibraryInspection>(
    context,
    (context) => SheetFrame(
      title: 'Из моих осмотров',
      subtitle:
          'Ваши осмотры за ${page.days} дней — добавьте машину без нового '
          'выезда. Заказчик сразу увидит отчёт.',
      children: [
        for (final item in page.items)
          _LibraryRow(
            item: item,
            onTap: () => Navigator.of(context).pop(item),
          ),
      ],
    ),
  );
  if (picked == null || !context.mounted) return null;

  final date = picked.completedAt;
  final confirmed = await showConfirmSheet(
    context,
    title: 'Машина ещё продаётся?',
    text:
        '${date != null ? 'Осмотр от ${dayMonth(date)}. ' : ''}'
        'Уточните у продавца, что ${picked.car.title} не продана: '
        'заказчик сразу увидит отчёт.',
    confirmLabel: 'Да, добавить',
  );
  return confirmed ? picked : null;
}

/// Строка библиотеки — как карточка кандидата: машина, вердикт, давность и
/// город, пробег по одометру и хвост VIN, чтобы отличить две одинаковые.
class _LibraryRow extends StatelessWidget {
  const _LibraryRow({required this.item, required this.onTap});

  final LibraryInspection item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final car = item.car;
    final date = item.completedAt;
    final meta = [
      if (date != null) inspectedAgo(date),
      if (item.city != null) item.city!,
    ].join(' · ');
    final details = [
      if (car.mileageKm != null) '${money(car.mileageKm!)} км',
      car.vinMasked,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: c.bg1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: c.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
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
                      if (item.verdict != null) ...[
                        const SizedBox(height: 7),
                        Pill(
                          item.verdict!.label.toLowerCase(),
                          color: item.verdict!.color(c),
                        ),
                      ],
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          meta,
                          style: TextStyle(fontSize: 12, color: c.text2),
                        ),
                      ],
                      const SizedBox(height: 3),
                      Text(
                        details,
                        style: TextStyle(fontSize: 12, color: c.text2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, size: 20, color: c.text2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
