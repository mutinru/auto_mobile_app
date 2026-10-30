import 'package:flutter/material.dart';

/// Категория пушей — зеркалит App\Enums\NotificationCategory на бекенде.
/// Глушится только пуш, лента пишется всегда. [critical] не глушится.
enum NotificationCategory {
  responses('responses', 'Отклики и исполнители',
      'Новые отклики, назначение и снятие исполнителя', Icons.person_search_outlined),
  progress('progress', 'Ход заказа и отчёт',
      'Отчёт готов или открыт, заказ завершён или отменён', Icons.assignment_outlined),
  reviews('reviews', 'Отзывы', 'Новый отзыв о вашей работе', Icons.star_outline),
  critical('critical', 'Оплата, споры и сроки',
      'Важно для оплаты и сроков — не отключается', Icons.priority_high);

  const NotificationCategory(this.apiValue, this.title, this.caption, this.icon);

  final String apiValue;
  final String title;
  final String caption;
  final IconData icon;

  bool get mutable => this != NotificationCategory.critical;

  /// Неизвестный этой сборке код — null: пропускаем.
  static NotificationCategory? fromApi(String value) {
    for (final c in values) {
      if (c.apiValue == value) return c;
    }
    return null;
  }
}
