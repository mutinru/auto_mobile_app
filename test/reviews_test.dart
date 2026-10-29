import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/api_exception.dart';
import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/review.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/screens/inspection_order_detail_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/util/ru_plural.dart';
import 'package:auto_podbor_mobile/widgets/executor_stats.dart';
import 'package:auto_podbor_mobile/widgets/review_sheet.dart';

/// Рейтинг исполнителя в откликах и отзыв заказчика после завершения.
void main() {
  group('модели', () {
    test('рейтинг приходит и целым, и дробным; без ключей — нули', () {
      expect(
        UserSummary.fromJson({'id': 1, 'name': 'А', 'rating': 5, 'reviews_count': 1}).rating,
        5.0,
      );
      expect(UserSummary.fromJson({'id': 1, 'name': 'А', 'rating': 4.8}).rating, 4.8);

      final old = UserSummary.fromJson({'id': 1, 'name': 'А'});
      expect(old.rating, isNull);
      expect(old.reviewsCount, 0);
      expect(old.completedOrdersCount, 0);
      expect(old.isNewcomer, isTrue);
    });

    test('без ключей review/can_review заказ оценить нельзя', () {
      final order = Order.fromJson({
        'id': 1,
        'status': 'completed',
        'brand': 'Kia',
        'model': 'Rio',
        'customer': {'id': 1, 'name': 'А'},
      });
      expect(order.canReview, isFalse);
      expect(order.review, isNull);
    });

    test('plural', () {
      String r(int n) => plural(n, 'отзыв', 'отзыва', 'отзывов');
      expect(r(1), 'отзыв');
      expect(r(2), 'отзыва');
      expect(r(5), 'отзывов');
      expect(r(11), 'отзывов');
      expect(r(21), 'отзыв');
      expect(r(112), 'отзывов');
    });

    test('userMessage берёт первую ошибку валидации, затем message', () {
      expect(
        ApiException(422, '{"message":"x","errors":{"text":["При оценке 1–2 опишите"]}}')
            .userMessage,
        'При оценке 1–2 опишите',
      );
      expect(ApiException(422, '{"message":"Отзыв уже оставлен"}').userMessage,
          'Отзыв уже оставлен');
      expect(ApiException(500, 'Bad Gateway').userMessage, 'Bad Gateway');
    });
  });

  group('ExecutorStats', () {
    Future<void> pump(WidgetTester tester, UserSummary user) => tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(body: ExecutorStats(user: user)),
          ),
        );

    testWidgets('рейтинг, отзывы и заказы', (tester) async {
      await pump(
        tester,
        const UserSummary(
          id: 1,
          name: 'М',
          rating: 4.8,
          reviewsCount: 12,
          completedOrdersCount: 30,
        ),
      );
      expect(find.text('★ 4.8 · 12 отзывов · 30 заказов', findRichText: true),
          findsOneWidget);
    });

    testWidgets('один отзыв — «★ 5.0 · 1 отзыв»', (tester) async {
      await pump(
        tester,
        const UserSummary(id: 1, name: 'М', rating: 5, reviewsCount: 1),
      );
      expect(find.text('★ 5.0 · 1 отзыв', findRichText: true), findsOneWidget);
    });

    testWidgets('без отзывов — «Новый исполнитель», а не ноль', (tester) async {
      await pump(tester, const UserSummary(id: 1, name: 'О'));
      expect(find.text('Новый исполнитель', findRichText: true), findsOneWidget);
      expect(find.textContaining('★'), findsNothing);
    });
  });

  group('ReviewSheet', () {
    final order = Order(
      id: 7,
      status: OrderStatus.completed,
      brand: 'Kia',
      model: 'Rio',
      customer: const UserSummary(id: 1, name: 'Андрей С.'),
      executor: const UserSummary(id: 10, name: 'Максим К.'),
    );

    Future<void> open(
      WidgetTester tester, {
      Review? initial,
      required Future<void> Function(int, String?) onSubmit,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showReviewSheet(
                  context,
                  order: order,
                  initial: initial,
                  onSubmit: onSubmit,
                ),
                child: const Text('открыть'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('открыть'));
      await tester.pumpAndSettle();
    }

    ElevatedButton submit(WidgetTester tester) =>
        tester.widget<ElevatedButton>(find.byType(ElevatedButton));

    testWidgets('оценка 1–2 требует текст от 10 символов', (tester) async {
      (int, String?)? sent;
      await open(tester, onSubmit: (r, t) async => sent = (r, t));

      expect(submit(tester).onPressed, isNull, reason: 'оценка не выбрана');

      await tester.tap(find.byKey(const ValueKey('review-star-2')));
      await tester.pump();
      expect(find.text('При оценке 1–2 опишите, что пошло не так'), findsOneWidget);
      expect(submit(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Опоздал');
      await tester.pump();
      expect(submit(tester).onPressed, isNull, reason: 'меньше 10 символов');

      await tester.enterText(find.byType(TextField), 'Опоздал на два часа');
      await tester.pump();
      await tester.tap(find.text('Отправить'));
      await tester.pumpAndSettle();

      expect(sent, (2, 'Опоздал на два часа'));
      expect(find.text('Оцените исполнителя'), findsNothing, reason: 'лист закрылся');
    });

    testWidgets('высокая оценка уходит без текста', (tester) async {
      (int, String?)? sent;
      await open(tester, onSubmit: (r, t) async => sent = (r, t));

      await tester.tap(find.byKey(const ValueKey('review-star-5')));
      await tester.pump();
      await tester.tap(find.text('Отправить'));
      await tester.pumpAndSettle();

      expect(sent, (5, null));
    });

    testWidgets('правка открывается с прежней оценкой и сроком', (tester) async {
      final now = DateTime.now();
      await open(
        tester,
        initial: Review(
          id: 1,
          rating: 4,
          text: 'Хорошо',
          editableUntil: now.add(const Duration(hours: 5)),
          createdAt: now,
        ),
        onSubmit: (_, _) async {},
      );

      expect(find.text('Изменить отзыв'), findsOneWidget);
      expect(find.text('Хорошо'), findsOneWidget);
      expect(find.textContaining('Изменить можно до'), findsOneWidget);
      expect(submit(tester).onPressed, isNotNull);
    });

    testWidgets('ошибка сервера остаётся в листе', (tester) async {
      await open(
        tester,
        onSubmit: (_, _) async => throw ApiException(
          422,
          '{"message":"Срок для отзыва истёк"}',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('review-star-4')));
      await tester.pump();
      await tester.tap(find.text('Отправить'));
      await tester.pumpAndSettle();

      expect(find.text('Срок для отзыва истёк'), findsOneWidget);
      expect(find.text('Оцените исполнителя'), findsOneWidget);
    });
  });

  group('карточка заказа', () {
    OrderStore store() => OrderStore(
          MockOrderRepository(),
          catalog: MockCarCatalogRepository(),
          cities: MockCityRepository(),
        );

    testWidgets('отклики показывают рейтинг и «Новый исполнитель»', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: InspectionOrderDetailScreen(store: store(), orderId: 2053),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('★ 4.9 · 12 отзывов · 30 заказов', findRichText: true),
          findsOneWidget);
      expect(find.text('Новый исполнитель', findRichText: true), findsOneWidget);
    });

    testWidgets('завершённый заказ: оставить отзыв, затем «Ваш отзыв»',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: InspectionOrderDetailScreen(store: store(), orderId: 2047),
        ),
      );
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('Оставить отзыв'),
        find.byType(ListView),
        const Offset(0, -150),
      );
      await tester.tap(find.text('Оставить отзыв'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('review-star-5')));
      await tester.pump();
      await tester.tap(find.text('Отправить'));
      await tester.pumpAndSettle();

      expect(find.text('Оставить отзыв'), findsNothing);
      await tester.dragUntilVisible(
        find.text('Изменить отзыв'),
        find.byType(ListView),
        const Offset(0, -150),
      );
      expect(find.text('ВАШ ОТЗЫВ'), findsOneWidget);
      // сводку исполнителя пересчитал «сервер» (мок): было 12 отзывов
      expect(find.textContaining('13 отзывов', findRichText: true), findsOneWidget);
    });
  });
}
