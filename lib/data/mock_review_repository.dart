import '../models/review.dart';
import 'mock_backend.dart';
import 'mock_fixtures.dart';
import 'review_repository.dart';

/// Отзывы исполнителя для тестов: две записи, без страниц.
class MockReviewRepository implements ReviewRepository {
  MockReviewRepository(this.backend);

  final MockBackend backend;

  @override
  Future<ReviewPage> fetchExecutorReviews(int userId, {int page = 1}) async {
    final now = DateTime.now();
    return ReviewPage(
      items: [
        Review(
          id: 1,
          rating: 5,
          text: 'Нашёл машину за неделю, все косяки показал на месте.',
          editableUntil: now,
          createdAt: now.subtract(const Duration(days: 3)),
          customer: MockFixtures.me,
          orderTitle: 'Kia Sportage',
        ),
        Review(
          id: 2,
          rating: 4,
          editableUntil: now,
          createdAt: now.subtract(const Duration(days: 20)),
          customer: MockFixtures.me,
          orderTitle: 'Skoda Octavia',
        ),
      ],
      hasMore: false,
    );
  }
}
