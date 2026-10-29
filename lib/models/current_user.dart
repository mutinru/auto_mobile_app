import 'payout.dart';
import 'user_summary.dart';

/// Текущий пользователь (GET /api/me).
class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.registeredAt,
    this.rating,
    this.reviewsCount = 0,
    this.completedOrdersCount = 0,
    this.payout,
  });

  final int id;
  final String name;
  final String email;

  /// `+79001234567`; null — аккаунт входит по почте и номер не привязан.
  final String? phone;
  final DateTime? registeredAt;

  /// Своя сводка исполнителя для профиля; rating == null — отзывов нет.
  final double? rating;
  final int reviewsCount;
  final int completedOrdersCount;

  /// Свои реквизиты для оплаты разового осмотра; null — ещё не указаны,
  /// тогда форма отклика на осмотр их спросит.
  final Payout? payout;

  /// Тот же пользователь в форме, которую понимают ExecutorStats и экран
  /// отзывов.
  UserSummary get asSummary => UserSummary(
        id: id,
        name: name,
        rating: rating,
        reviewsCount: reviewsCount,
        completedOrdersCount: completedOrdersCount,
      );

  /// «с марта 2026» — вторая строка в шапке профиля.
  String get registeredLabel {
    final d = registeredAt;
    if (d == null) return '';
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    return 'с ${months[d.month - 1]} ${d.year}';
  }

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        registeredAt: json['registered_at'] != null
            ? DateTime.tryParse(json['registered_at'] as String)
            : null,
        // PHP отдаёт и 5, и 4.8 — num, а не double
        rating: (json['rating'] as num?)?.toDouble(),
        reviewsCount: json['reviews_count'] as int? ?? 0,
        completedOrdersCount: json['completed_orders_count'] as int? ?? 0,
        payout: json['payout'] != null
            ? Payout.fromJson(json['payout'] as Map<String, dynamic>)
            : null,
      );
}
