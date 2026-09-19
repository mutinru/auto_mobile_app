import 'order_status.dart';

/// Шаг таймлайна «Как шла работа» на публичной карточке заказа.
class TimelineStep {
  const TimelineStep({required this.title, required this.done, this.at});

  final String title;
  final bool done;
  final DateTime? at;

  factory TimelineStep.fromJson(Map<String, dynamic> json) => TimelineStep(
        title: json['title'] as String,
        done: json['done'] as bool,
        at: json['at'] != null ? DateTime.tryParse(json['at'] as String) : null,
      );
}

/// Публичный просмотр заказа (GET /api/public/orders/{id}) — экран 02
/// из car-marketplace-experiment.html. Фото и контактов здесь нет:
/// бекенд их не отдаёт анониму.
class PublicOrder {
  const PublicOrder({
    required this.id,
    required this.status,
    required this.car,
    required this.timeline,
    this.city,
    this.budgetMin,
    this.budgetMax,
    this.requirements = const [],
    this.carsInspected = 0,
    this.carsRejected = 0,
    this.executorName,
    this.executorCompleted,
  });

  final int id;
  final OrderStatus status;
  final String car;
  final String? city;
  final int? budgetMin;
  final int? budgetMax;
  final List<String> requirements;
  final int carsInspected;
  final int carsRejected;
  final String? executorName;
  final int? executorCompleted;
  final List<TimelineStep> timeline;

  factory PublicOrder.fromJson(Map<String, dynamic> json) {
    final executor = json['executor'] as Map<String, dynamic>?;
    return PublicOrder(
      id: json['id'] as int,
      status: orderStatusFromApi(json['status'] as String),
      car: json['car'] as String,
      city: json['city'] as String?,
      budgetMin: json['budget_min'] as int?,
      budgetMax: json['budget_max'] as int?,
      requirements: (json['requirements'] as List?)?.cast<String>() ?? const [],
      carsInspected: json['cars_inspected'] as int? ?? 0,
      carsRejected: json['cars_rejected'] as int? ?? 0,
      executorName: executor?['name'] as String?,
      executorCompleted: executor?['completed_orders'] as int?,
      timeline: (json['timeline'] as List? ?? const [])
          .map((t) => TimelineStep.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }
}
