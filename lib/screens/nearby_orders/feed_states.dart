import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/app_ui.dart';

/// Лента не загрузилась: причина и «Повторить».
class NearbyFeedError extends StatelessWidget {
  const NearbyFeedError({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Не удалось загрузить заказы',
            style: TextStyle(fontSize: 14, color: context.colors.text1),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: context.colors.text3),
          ),
          const SizedBox(height: 10),
          CtaGhost(label: 'Повторить', onPressed: onRetry),
        ],
      ),
    );
  }
}

/// Пустая лента — с причиной: город по GPS, фильтры или заказов нет вовсе.
class NearbyFeedEmpty extends StatelessWidget {
  const NearbyFeedEmpty({
    super.key,
    required this.hiddenByFilter,
    required this.onlyAutoCity,
    required this.onShowAllCities,
    required this.onResetFilters,
  });

  /// Свободные заказы есть — ленту опустошили фильтры.
  final bool hiddenByFilter;

  /// Опустошил только город по GPS — предлагаем все города.
  final String? onlyAutoCity;
  final VoidCallback onShowAllCities;
  final VoidCallback onResetFilters;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 13, color: context.colors.text2);
    if (hiddenByFilter && onlyAutoCity != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          children: [
            Text(
              'В городе $onlyAutoCity свободных заказов нет',
              textAlign: TextAlign.center,
              style: style,
            ),
            const SizedBox(height: 6),
            CtaGhost(label: 'Показать все города', onPressed: onShowAllCities),
          ],
        ),
      );
    }
    if (hiddenByFilter) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          children: [
            Text('Под фильтр ничего не подошло', style: style),
            const SizedBox(height: 6),
            CtaGhost(label: 'Сбросить фильтры', onPressed: onResetFilters),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Center(child: Text('Свободных заказов сейчас нет', style: style)),
    );
  }
}
