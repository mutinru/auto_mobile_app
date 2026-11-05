import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/data/mock_verification_repository.dart';
import 'dart:async';

import 'package:auto_podbor_mobile/data/api_exception.dart';
import 'package:auto_podbor_mobile/data/location_service.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_kind.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/state/city_locator.dart';
import 'package:auto_podbor_mobile/state/nearby_filter_store.dart';
import 'package:auto_podbor_mobile/data/verification_repository.dart';
import 'package:auto_podbor_mobile/models/available_page.dart';
import 'package:auto_podbor_mobile/models/nearby_filter.dart';
import 'package:auto_podbor_mobile/screens/nearby_orders_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/state/verification_status.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

/// Мок, у которого вторая и дальше страницы ленты не грузятся.
class _FailingMorePages extends MockOrderRepository {
  _FailingMorePages() : super(availablePageSize: 1);

  @override
  Future<AvailablePage> fetchAvailableOrders({
    NearbyFilter filter = const NearbyFilter(),
    bool fewResponses = false,
    int page = 1,
  }) async {
    if (page > 1) throw ApiException(500, '{"message":"Сбой"}');
    return super.fetchAvailableOrders(
      filter: filter,
      fewResponses: fewResponses,
      page: page,
    );
  }
}

/// Сводка верификации по команде теста: [next] — ответ или ошибка
/// следующего запроса, [calls] — сколько раз спросили.
class _ScriptedVerification implements VerificationRepository {
  Completer<VerificationSummary> next = Completer();
  int calls = 0;

  @override
  Future<VerificationSummary> fetchSummary() {
    calls++;
    return next.future;
  }
}

/// Геопозиция без плагина: [point] — что «вернул GPS».
class _Here implements LocationService {
  _Here(this.point);

  final (double, double)? point;

  @override
  Future<bool> isGranted() async => point != null;

  @override
  Future<(double, double)?> current() async => point;

  @override
  Future<LocationProblem?> problem() async => null;

  @override
  Future<void> openSettings(LocationProblem problem) async {}
}

const _verified = VerificationSummary(passed: 4, total: 4, complete: true);
const _unverified = VerificationSummary(passed: 1, total: 4, complete: false);

void main() {
  Widget app({
    int passed = 0,
    bool required = true,
    MockOrderRepository? repository,
    VerificationStatus? verification,
  }) => MaterialApp(
    theme: AppTheme.dark,
    home: NearbyOrdersScreen(
      store: OrderStore(
        repository ?? MockOrderRepository(),
        catalog: MockCarCatalogRepository(),
        cities: MockCityRepository(),
      ),
      verification:
          verification ??
          VerificationStatus(
            MockVerificationRepository(passed: passed, required: required),
          ),
    ),
  );

  /// Кнопка отклика внутри первой карточки: в моке теперь два свободных
  /// заказа — разовый осмотр и подбор.
  ElevatedButton respondButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(
        find
            .ancestor(
              of: find.text('Откликнуться'),
              matching: find.byType(ElevatedButton),
            )
            .first,
      );

  testWidgets('показывает свободный заказ и гейт верификации', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // мок отдаёт один заказ в статусе awaiting_executor и без города
    expect(find.text('Volkswagen Tiguan 2019+'), findsOneWidget);
    expect(find.text('Смотреть можно, откликаться — нет'), findsOneWidget);
    expect(find.text('Стать исполнителем'), findsOneWidget);

    // чужой отклик на 10 000 ₽ виден только числом — цены конкурента нет
    expect(find.text('Откликаются от'), findsNothing);
    expect(find.text('10 000 ₽'), findsNothing);
    expect(find.text('предлагаете вы'), findsOneWidget);
    expect(find.textContaining('1 отклик'), findsOneWidget);
  });

  testWidgets('без верификации кнопка отклика неактивна', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(respondButton(tester).onPressed, isNull);
  });

  testWidgets('после верификации гейт исчезает, отклик доступен', (
    tester,
  ) async {
    await tester.pumpWidget(app(passed: 4));
    await tester.pumpAndSettle();

    expect(find.text('Смотреть можно, откликаться — нет'), findsNothing);
    expect(respondButton(tester).onPressed, isNotNull);
  });

  testWidgets('верификация не обязательна — гейта нет, отклик доступен сразу', (
    tester,
  ) async {
    await tester.pumpWidget(app(required: false));
    await tester.pumpAndSettle();

    expect(find.text('Смотреть можно, откликаться — нет'), findsNothing);
    expect(respondButton(tester).onPressed, isNotNull);
  });

  test(
    'мок отдаёт исполнителю только свой отклик, остальные — числом',
    () async {
      final repo = MockOrderRepository();
      final tiguan = (await repo.fetchAvailableOrders()).items.firstWhere(
        (o) => o.brand == 'Volkswagen',
      );
      expect(tiguan.responses, isEmpty);
      expect(tiguan.responsesCount, 1);

      final after = await repo.respondToOrder(tiguan.id, proposedPrice: 9000);
      expect(after.responses.map((r) => r.proposedPrice), [9000]);
      expect(after.responsesCount, 2);
    },
  );

  testWidgets('после отклика заказ остаётся в ленте с погашенной кнопкой', (
    tester,
  ) async {
    final store = OrderStore(
      MockOrderRepository(),
      catalog: MockCarCatalogRepository(),
      cities: MockCityRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: NearbyOrdersScreen(
          store: store,
          verification: VerificationStatus(
            MockVerificationRepository(passed: 0, required: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Вы откликнулись'), findsNothing);

    final tiguan = store.availableOrders.firstWhere(
      (o) => o.brand == 'Volkswagen',
    );
    await store.respondToOrder(tiguan.id, proposedPrice: 9000);
    await tester.pumpAndSettle();

    expect(find.text('Volkswagen Tiguan 2019+'), findsOneWidget);
    expect(find.text('Ваш отклик'), findsOneWidget);
    expect(find.text('9 000 ₽'), findsOneWidget);
    expect(find.textContaining('2 отклика'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Вы откликнулись'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('фильтр «Мало откликов» оставляет заказ с одним откликом', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Мало откликов'));
    await tester.pumpAndSettle();

    expect(find.text('Volkswagen Tiguan 2019+'), findsOneWidget);
    // у BMW три отклика — «Мало откликов» фильтрует сервер (здесь мок)
    expect(find.text('BMW X3 2017'), findsNothing);
    expect(find.text('Все · 2'), findsOneWidget);
  });

  testWidgets('шторка фильтров: «Осмотр» прячет подбор, крестик возвращает', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Volkswagen Tiguan 2019+'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.text('Фильтры'), findsOneWidget);

    await tester.tap(find.text('Осмотр'));
    // счётчик спрашивается у сервера, когда правки затихли
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Показать 1 заказ'));
    await tester.pumpAndSettle();

    expect(find.text('Volkswagen Tiguan 2019+'), findsNothing);
    expect(find.text('BMW X3 2017'), findsOneWidget);
    // бейдж на кнопке и чип включённого фильтра под шапкой
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Осмотр  ✕'), findsOneWidget);

    await tester.tap(find.text('Осмотр  ✕'));
    await tester.pumpAndSettle();

    expect(find.text('Volkswagen Tiguan 2019+'), findsOneWidget);
    expect(find.text('Осмотр  ✕'), findsNothing);
  });

  testWidgets('лента подгружает следующую страницу, когда дошли до конца', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(repository: MockOrderRepository(availablePageSize: 1)),
    );
    await tester.pumpAndSettle();

    // первая страница короткая — подвал виден сразу и просит вторую
    expect(find.text('BMW X3 2017'), findsOneWidget);
    expect(find.text('Volkswagen Tiguan 2019+'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('сбой следующей страницы — «Повторить», загруженное на месте', (
    tester,
  ) async {
    await tester.pumpWidget(app(repository: _FailingMorePages()));
    await tester.pumpAndSettle();

    expect(find.text('BMW X3 2017'), findsOneWidget);
    expect(find.text('Volkswagen Tiguan 2019+'), findsNothing);
    expect(find.text('Повторить'), findsOneWidget);
  });

  testWidgets('пока статус верификации грузится — плашки нет, отклик закрыт', (
    tester,
  ) async {
    final repo = _ScriptedVerification();
    await tester.pumpWidget(app(verification: VerificationStatus(repo)));
    await tester.pumpAndSettle();

    expect(find.text('Смотреть можно, откликаться — нет'), findsNothing);
    expect(respondButton(tester).onPressed, isNull);

    repo.next.complete(_verified);
    await tester.pumpAndSettle();
    expect(find.text('Смотреть можно, откликаться — нет'), findsNothing);
    expect(respondButton(tester).onPressed, isNotNull);
  });

  testWidgets('сбой статуса — «Повторить», а не плашка про верификацию', (
    tester,
  ) async {
    final repo = _ScriptedVerification();
    await tester.pumpWidget(app(verification: VerificationStatus(repo)));
    repo.next.completeError(ApiException(500, '{"message":"Сбой"}'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось проверить верификацию'), findsOneWidget);
    expect(find.text('Смотреть можно, откликаться — нет'), findsNothing);

    repo.next = Completer()..complete(_verified);
    await tester.tap(find.widgetWithText(TextButton, 'Повторить'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось проверить верификацию'), findsNothing);
    expect(respondButton(tester).onPressed, isNotNull);
    expect(repo.calls, 2);
  });

  testWidgets('известный статус рисуется с первого кадра', (tester) async {
    final repo = _ScriptedVerification()..next.complete(_unverified);
    final status = VerificationStatus(repo);
    await status.refresh();
    // следующий запрос повиснет — экран не должен его ждать
    repo.next = Completer();

    await tester.pumpWidget(app(verification: status));
    await tester.pump();

    expect(find.text('Смотреть можно, откликаться — нет'), findsOneWidget);
    expect(find.textContaining('пройдено 1 из 4'), findsOneWidget);
  });

  group('«Ближе ко мне» (бэклог №29)', () {
    Order at(int id, String brand, double lat, double lon) => Order(
      id: id,
      kind: OrderKind.inspection,
      status: OrderStatus.awaitingExecutor,
      brand: brand,
      model: 'X',
      customer: const UserSummary(id: 7, name: 'Ольга'),
      cities: const ['Москва'],
      inspectOn: DateTime.now().add(const Duration(days: 1)),
      lat: lat,
      lon: lon,
    );

    Future<void> pumpNearest(
      WidgetTester tester,
      (double, double)? here,
    ) async {
      final filters = NearbyFilterStore();
      await filters.set(const NearbyFilter(sort: NearbySort.nearest));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: NearbyOrdersScreen(
            store: OrderStore(
              MockOrderRepository(
                orders: [
                  at(1, 'Podolsk', 55.4312, 37.5458),
                  at(2, 'Center', 55.7558, 37.6173),
                  at(3, 'Khimki', 55.8897, 37.4449),
                ],
              ),
              catalog: MockCarCatalogRepository(),
              cities: MockCityRepository(),
              locator: CityLocator(MockCityRepository(), _Here(here)),
            ),
            verification: VerificationStatus(
              MockVerificationRepository(passed: 4, required: false),
            ),
            filters: filters,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    double top(WidgetTester tester, String brand) =>
        tester.getTopLeft(find.textContaining(brand).first).dy;

    testWidgets('лента — по расстоянию от телефона', (tester) async {
      await pumpNearest(tester, (55.751, 37.618));
      expect(top(tester, 'Center'), lessThan(top(tester, 'Khimki')));
      expect(top(tester, 'Khimki'), lessThan(top(tester, 'Podolsk')));
      expect(find.textContaining('Геопозиция недоступна'), findsNothing);
    });

    testWidgets('без геопозиции — «новые» и строка об этом', (tester) async {
      await pumpNearest(tester, null);
      expect(
        find.text('Геопозиция недоступна — показаны новые заказы'),
        findsOneWidget,
      );
    });
  });

  group('шторка фильтров: свой город по геопозиции (QA 2026-11-05 №9)', () {
    Future<void> openOtherCity(
      WidgetTester tester, {
      CityLocator? locator,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: NearbyOrdersScreen(
            store: OrderStore(
              MockOrderRepository(),
              catalog: MockCarCatalogRepository(),
              cities: MockCityRepository(),
              locator: locator,
            ),
            verification: VerificationStatus(
              MockVerificationRepository(passed: 4, required: false),
            ),
            filters: NearbyFilterStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Осмотр'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Другой город…'));
      await tester.tap(find.text('Другой город…'));
      await tester.pumpAndSettle();
    }

    testWidgets('строка есть, город добавляется, «Осмотр» остаётся', (
      tester,
    ) async {
      await openOtherCity(
        tester,
        locator: CityLocator(MockCityRepository(), _Here((55.7558, 37.6173))),
      );
      expect(find.text('Определить по геопозиции'), findsOneWidget);

      await tester.tap(find.text('Определить по геопозиции'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Готово'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Показать'));
      await tester.pumpAndSettle();

      expect(find.text('Москва  ✕'), findsOneWidget);
      expect(find.text('Осмотр  ✕'), findsOneWidget);
    });

    testWidgets('без локатора строки нет', (tester) async {
      await openOtherCity(tester);
      expect(find.text('Определить по геопозиции'), findsNothing);
    });
  });
}
