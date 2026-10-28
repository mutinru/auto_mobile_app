/// Короткая сводка по верификации исполнителя — ровно то, что нужно
/// гейту на экране «Заказы рядом». Полный список шагов и уровней читает
/// [VerificationScreen] отдельным запросом.
class VerificationSummary {
  const VerificationSummary({
    required this.passed,
    required this.total,
    required this.complete,
    this.required = true,
    bool? canTakeOrders,
  }) : canTakeOrders = canTakeOrders ?? complete;

  factory VerificationSummary.fromJson(Map<String, dynamic> json) {
    final complete = json['complete'] as bool? ?? false;
    return VerificationSummary(
      passed: (json['passed'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 4,
      complete: complete,
      // старый бекенд этих полей не отдаёт — тогда верификация обязательна
      required: json['required'] as bool? ?? true,
      canTakeOrders: json['can_take_orders'] as bool? ?? complete,
    );
  }

  final int passed;
  final int total;
  final bool complete;

  /// Требует ли сервер верификацию для откликов. Пока она выключена флагом
  /// на бекенде — откликаться может любой.
  final bool required;

  /// Можно ли откликаться на заказы. Гейт смотрит сюда, а не на [complete].
  final bool canTakeOrders;

  /// Доля пройденных шагов — ширина полосы .gate-prog.
  double get progress => total == 0 ? 0 : passed / total;
}

abstract class VerificationRepository {
  Future<VerificationSummary> fetchSummary();
}
