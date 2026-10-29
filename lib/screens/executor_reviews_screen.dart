import 'package:flutter/material.dart';

import '../data/order_repository.dart';
import '../models/review.dart';
import '../models/user_summary.dart';
import '../theme/app_colors.dart';
import '../util/ru_date.dart';
import '../widgets/api_error.dart';
import '../widgets/app_ui.dart';
import '../widgets/executor_stats.dart';

/// Открыть отзывы об исполнителе из отклика или блока «Исполнитель».
Future<void> openExecutorReviews(
  BuildContext context,
  OrderRepository repository,
  UserSummary executor,
) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          ExecutorReviewsScreen(repository: repository, executor: executor),
    ),
  );
}

/// Отзывы заказчиков об исполнителе, свежие сверху (GET /users/{id}/reviews).
/// Макета нет — карточки собраны как .resp из order-types.html.
class ExecutorReviewsScreen extends StatefulWidget {
  const ExecutorReviewsScreen({
    super.key,
    required this.repository,
    required this.executor,
  });

  final OrderRepository repository;
  final UserSummary executor;

  @override
  State<ExecutorReviewsScreen> createState() => _ExecutorReviewsScreenState();
}

class _ExecutorReviewsScreenState extends State<ExecutorReviewsScreen> {
  final List<Review> _reviews = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.fetchExecutorReviews(
        widget.executor.id,
        page: _page + 1,
      );
      if (mounted) {
        setState(() {
          _reviews.addAll(page.items);
          _page++;
          _hasMore = page.hasMore;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            DetailHead(
              title: widget.executor.name,
              eyebrow: 'отзывы',
              onBack: () => Navigator.of(context).pop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ExecutorStats(user: widget.executor),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null && _reviews.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Не удалось загрузить отзывы',
              style: TextStyle(fontSize: 14, color: context.colors.text1),
            ),
            const SizedBox(height: 6),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: context.colors.text3),
            ),
            const SizedBox(height: 10),
            CtaGhost(label: 'Повторить', onPressed: _loadMore),
          ],
        ),
      );
    }

    if (_reviews.isEmpty) {
      return _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Text(
                'Отзывов пока нет',
                style: TextStyle(fontSize: 13, color: context.colors.text2),
              ),
            );
    }

    return NotificationListener<ScrollNotification>(
      // следующая страница — когда до конца списка меньше экрана
      onNotification: (n) {
        if (n.metrics.extentAfter < 400) _loadMore();
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
        itemCount: _reviews.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _reviews.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _error != null
                    ? CtaGhost(label: 'Повторить', onPressed: _loadMore)
                    : const CircularProgressIndicator(),
              ),
            );
          }
          return _ReviewCard(review: _reviews[i]);
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.bg1,
        border: Border.all(color: context.colors.line),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RatingStars(rating: review.rating),
          if (review.text != null && review.text!.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              review.text!,
              style: TextStyle(
                fontSize: 12.5,
                color: context.colors.text1,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 7),
          Text(
            [
              if (review.customer != null) review.customer!.name,
              if (review.orderTitle != null) review.orderTitle!,
              dayMonth(review.createdAt),
            ].join(' · '),
            style: TextStyle(fontSize: 11, color: context.colors.text3),
          ),
        ],
      ),
    );
  }
}
