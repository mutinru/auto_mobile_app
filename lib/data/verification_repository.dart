/// Короткая сводка по верификации исполнителя — ровно то, что нужно
/// гейту на экране «Заказы рядом». Полный список шагов и уровней читает
/// [VerificationScreen] отдельным запросом.
class VerificationSummary {
  const VerificationSummary({
    required this.passed,
    required this.total,
    required this.complete,
  });

  factory VerificationSummary.fromJson(Map<String, dynamic> json) {
    return VerificationSummary(
      passed: (json['passed'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 4,
      complete: json['complete'] as bool? ?? false,
    );
  }

  final int passed;
  final int total;
  final bool complete;

  /// Доля пройденных шагов — ширина полосы .gate-prog.
  double get progress => total == 0 ? 0 : passed / total;
}

abstract class VerificationRepository {
  Future<VerificationSummary> fetchSummary();
}
