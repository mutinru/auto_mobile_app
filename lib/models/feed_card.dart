import '../models/order_status.dart';

/// Карточка публичной витрины (GET /api/public/feed).
class FeedCard {
  const FeedCard({
    required this.id,
    required this.status,
    required this.car,
    this.city,
    this.budgetMax,
    this.executorName,
    this.executorCompleted,
    this.assessed,
    this.total,
    this.carIndex,
  });

  final int id;
  final OrderStatus status;
  final String car;
  final String? city;
  final int? budgetMax;
  final String? executorName;
  final int? executorCompleted;

  /// прогресс последнего осмотра, если он начат
  final int? assessed;
  final int? total;
  final int? carIndex;

  bool get hasProgress => total != null && total! > 0;
  double get progressFraction => hasProgress ? (assessed ?? 0) / total! : 0;

  factory FeedCard.fromJson(Map<String, dynamic> json) {
    final progress = json['progress'] as Map<String, dynamic>?;
    final executor = json['executor'] as Map<String, dynamic>?;
    return FeedCard(
      id: json['id'] as int,
      status: orderStatusFromApi(json['status'] as String),
      car: json['car'] as String,
      city: json['city'] as String?,
      budgetMax: json['budget_max'] as int?,
      executorName: executor?['name'] as String?,
      executorCompleted: executor?['completed_orders'] as int?,
      assessed: progress?['assessed'] as int?,
      total: progress?['total'] as int?,
      carIndex: progress?['car_index'] as int?,
    );
  }
}

/// Счётчики над лентой (.feed-stats).
class FeedStats {
  const FeedStats({
    required this.completed,
    required this.inProgress,
    required this.inspections,
  });

  final int completed;
  final int inProgress;
  final int inspections;

  factory FeedStats.fromJson(Map<String, dynamic> json) => FeedStats(
        completed: json['completed'] as int,
        inProgress: json['in_progress'] as int,
        inspections: json['inspections'] as int,
      );
}
