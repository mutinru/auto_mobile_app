import 'package:flutter/material.dart';

import '../models/user_summary.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../util/ru_plural.dart';

/// .resp-stats из order-types.html (кадр 04): «★ 4.9 · 12 отзывов · 30
/// заказов». Без отзывов — «Новый исполнитель», а не «★ 0.0»: ноль
/// читается как плохая оценка.
class ExecutorStats extends StatelessWidget {
  const ExecutorStats({super.key, required this.user, this.onTap});

  final UserSummary user;

  /// Открыть отзывы об исполнителе; null — строка не нажимается.
  final VoidCallback? onTap;

  /// Подпись без звезды — для тестов и семантики.
  static String summary(UserSummary user) => [
        if (user.isNewcomer)
          'Новый исполнитель'
        else
          counted(user.reviewsCount, 'отзыв', 'отзыва', 'отзывов'),
        if (user.completedOrdersCount > 0)
          counted(user.completedOrdersCount, 'заказ', 'заказа', 'заказов'),
      ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: AppTheme.monoFamily,
      fontSize: 11,
      color: context.colors.text3,
    );

    final text = Text.rich(
      TextSpan(
        style: style,
        children: [
          if (!user.isNewcomer && user.rating != null) ...[
            TextSpan(
              text: '★ ${user.rating!.toStringAsFixed(1)}',
              style: TextStyle(color: context.colors.statusProgress),
            ),
            const TextSpan(text: ' · '),
          ],
          TextSpan(text: summary(user)),
        ],
      ),
    );

    if (onTap == null) return text;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: text),
    );
  }
}

/// Ряд звёзд оценки: залитые — до [rating], остальные контуром.
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.rating, this.size = 14});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i <= rating ? context.colors.statusProgress : context.colors.text3,
          ),
      ],
    );
  }
}
