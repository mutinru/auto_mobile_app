import 'user_summary.dart';

/// Отзыв заказчика об исполнителе (ReviewResource на бекенде). Один на
/// заказ; править можно до [editableUntil] — срок считает сервер.
class Review {
  const Review({
    required this.id,
    required this.rating,
    required this.editableUntil,
    required this.createdAt,
    this.text,
    this.customer,
    this.orderTitle,
  });

  final int id;

  /// 1–5.
  final int rating;
  final String? text;
  final DateTime editableUntil;
  final DateTime createdAt;

  /// Есть только в ленте отзывов об исполнителе (GET /users/{id}/reviews).
  final UserSummary? customer;

  /// «Kia Rio» — о каком заказе отзыв, тоже только в ленте.
  final String? orderTitle;

  bool get isEditable => DateTime.now().isBefore(editableUntil);

  factory Review.fromJson(Map<String, dynamic> json) {
    final order = json['order'] as Map<String, dynamic>?;
    return Review(
      id: json['id'] as int,
      rating: json['rating'] as int,
      text: json['text'] as String?,
      editableUntil: DateTime.parse(json['editable_until'] as String).toLocal(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      customer: json['customer'] != null
          ? UserSummary.fromJson(json['customer'] as Map<String, dynamic>)
          : null,
      orderTitle: order != null ? '${order['brand']} ${order['model']}' : null,
    );
  }
}

/// Страница ленты отзывов: бекенд пагинирует по 20.
class ReviewPage {
  const ReviewPage({required this.items, required this.hasMore});

  final List<Review> items;
  final bool hasMore;
}
