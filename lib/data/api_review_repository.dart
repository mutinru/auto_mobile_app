import '../models/review.dart';
import 'api_client.dart';
import 'json_list.dart';
import 'review_repository.dart';

/// Отзывы исполнителя (GET /users/{id}/reviews).
class ApiReviewRepository implements ReviewRepository {
  ApiReviewRepository(this._client);

  final ApiClient _client;

  @override
  Future<ReviewPage> fetchExecutorReviews(int userId, {int page = 1}) async {
    final json = await _client.get('/users/$userId/reviews?page=$page');
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    return ReviewPage(
      items: parseList(json['data'], Review.fromJson, what: 'отзыв'),
      hasMore:
          (meta['current_page'] as int? ?? 1) <
          (meta['last_page'] as int? ?? 1),
    );
  }
}
