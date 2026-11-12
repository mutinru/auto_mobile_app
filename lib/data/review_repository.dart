import '../models/review.dart';

/// Отзывы об исполнителе — страница профиля исполнителя. Оставить или
/// поправить отзыв по заказу — [OrderRepository.leaveReview]: ответ — заказ.
abstract class ReviewRepository {
  /// Отзывы об исполнителе, свежие сверху; [page] с 1.
  Future<ReviewPage> fetchExecutorReviews(int userId, {int page = 1});
}
