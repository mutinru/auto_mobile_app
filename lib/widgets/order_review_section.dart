import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme/app_colors.dart';
import '../util/ru_date.dart';
import 'app_ui.dart';
import 'executor_stats.dart';

/// Отзыв в карточке завершённого заказа. Заказчику — «Оставить отзыв»,
/// пока сервер разрешает (canReview), или его отзыв с «Изменить» в
/// пределах 24 часов. Исполнителю — отзыв заказчика только на чтение.
/// Ничего не рисует, если отзыва нет и оставить его нельзя.
class OrderReviewSection extends StatelessWidget {
  const OrderReviewSection({
    super.key,
    required this.order,
    required this.viewerIsCustomer,
    required this.onWrite,
  });

  final Order order;
  final bool viewerIsCustomer;

  /// Открыть лист отзыва: новый, если отзыва ещё нет, иначе правка.
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    final review = order.review;

    if (review == null) {
      if (!viewerIsCustomer || !order.canReview) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 22),
          const SectionHead('Оцените исполнителя'),
          Text(
            'Отзыв увидят другие заказчики, когда будут выбирать исполнителя',
            style: TextStyle(fontSize: 12.5, color: context.colors.text2),
          ),
          const SizedBox(height: 12),
          CtaPrimary(
            label: 'Оставить отзыв',
            icon: Icons.star_rounded,
            onPressed: onWrite,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        SectionHead(
          viewerIsCustomer ? 'Ваш отзыв' : 'Отзыв заказчика',
          extra: dayMonth(review.createdAt),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: context.colors.bg1,
            border: Border.all(color: context.colors.line),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RatingStars(rating: review.rating, size: 18),
              if (review.text != null && review.text!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  review.text!,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: context.colors.text1,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (viewerIsCustomer && review.isEditable)
          CtaGhost(label: 'Изменить отзыв', onPressed: onWrite),
      ],
    );
  }
}
