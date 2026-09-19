import 'verification_repository.dart';

/// Мок для тестов: по умолчанию — состояние сидера (ни один шаг не пройден).
class MockVerificationRepository implements VerificationRepository {
  MockVerificationRepository({this.passed = 0, this.total = 4});

  final int passed;
  final int total;

  @override
  Future<VerificationSummary> fetchSummary() async => VerificationSummary(
        passed: passed,
        total: total,
        complete: passed >= total,
      );
}
