import 'package:flutter/material.dart';

import '../models/order_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Лист выбора вида заказа (order-types.html, кадр 02): «Новый заказ»
/// и «+» в шапке открывают один и тот же лист. Возвращает выбранный вид
/// или null, если лист закрыли.
Future<OrderKind?> showOrderKindSheet(BuildContext context) {
  return showModalBottomSheet<OrderKind>(
    context: context,
    backgroundColor: context.colors.bg0,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) => const _OrderKindSheet(),
  );
}

class _OrderKindSheet extends StatelessWidget {
  const _OrderKindSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // .sheet-handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: context.colors.bg3,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Что нужно сделать?',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.34,
              color: context.colors.text1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'От этого зависит форма заказа и кто откликнется',
            style: TextStyle(fontSize: 12, color: context.colors.text2),
          ),
          const SizedBox(height: 14),
          _KindOption(
            kind: OrderKind.selection,
            icon: Icons.search,
            iconBg: context.colors.modeBuy,
            iconInk: context.colors.modeBuyInk,
            name: 'Подобрать автомобиль',
            description: 'Знаю, чего хочу, но машины ещё нет. '
                'Подборщик найдёт варианты и проверит лучшие.',
            facts: const ['недели', 'несколько машин'],
          ),
          _KindOption(
            kind: OrderKind.inspection,
            icon: Icons.assignment_outlined,
            iconBg: context.colors.statusInfo,
            iconInk: context.colors.infoInk,
            name: 'Осмотреть конкретную машину',
            description: 'Нашёл объявление. Специалист приедет по адресу, '
                'проверит кузов по 13 деталям и пришлёт отчёт.',
            facts: const ['1–2 дня', 'одна машина', 'отчёт'],
          ),
        ],
      ),
    );
  }
}

/// .kind-opt
class _KindOption extends StatelessWidget {
  const _KindOption({
    required this.kind,
    required this.icon,
    required this.iconBg,
    required this.iconInk,
    required this.name,
    required this.description,
    required this.facts,
  });

  final OrderKind kind;
  final IconData icon;
  final Color iconBg;
  final Color iconInk;
  final String name;
  final String description;
  final List<String> facts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: () => Navigator.of(context).pop(kind),
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colors.bg1,
            border: Border.all(color: context.colors.line, width: 1.5),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 19, color: iconInk),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.145,
                        color: context.colors.text1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.colors.text2,
                        height: 1.42,
                      ),
                    ),
                    const SizedBox(height: 9),
                    // .kind-opt-facts
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final fact in facts)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.bg0,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              fact,
                              style: TextStyle(
                                fontFamily: AppTheme.monoFamily,
                                fontSize: 10.5,
                                color: context.colors.text2,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
