/// Представление пользователя в контексте заказа (UserResource на бекенде):
/// без контактов, но со сводкой исполнителя — она нужна в откликах.
class UserSummary {
  const UserSummary({
    required this.id,
    required this.name,
    this.rating,
    this.reviewsCount = 0,
    this.completedOrdersCount = 0,
  });

  final int id;
  final String name;

  /// Средняя оценка с одним знаком; null, пока отзывов нет. Считает сервер,
  /// локально не пересчитываем.
  final double? rating;
  final int reviewsCount;
  final int completedOrdersCount;

  /// «Новый исполнитель» — отзывов ещё нет.
  bool get isNewcomer => reviewsCount == 0;

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
        id: json['id'] as int,
        name: json['name'] as String,
        // PHP отдаёт и 5, и 4.8 — num, а не double
        rating: (json['rating'] as num?)?.toDouble(),
        reviewsCount: json['reviews_count'] as int? ?? 0,
        completedOrdersCount: json['completed_orders_count'] as int? ?? 0,
      );
}
