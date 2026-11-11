import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/current_user.dart';
import 'package:auto_podbor_mobile/models/inspection_verdict.dart';
import 'package:auto_podbor_mobile/models/library_inspection.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_car.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/screens/order_detail_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/util/ru_date.dart';

/// Библиотека осмотров исполнителя: свой готовый осмотр — кандидатом
/// подбора, с подтверждением «машина ещё продаётся».
void main() {
  const customer = UserSummary(id: 1, name: 'Максим К.');
  const executor = UserSummary(id: 10, name: 'Игорь В.');

  final order = Order(
    id: 4101,
    status: OrderStatus.sourcing,
    brand: 'Toyota',
    model: 'RAV4',
    yearFrom: 2018,
    customer: customer,
    executor: executor,
    price: 20000,
  );

  LibraryInspection item({int id = 77, int daysAgo = 5}) => LibraryInspection(
    inspectionId: id,
    car: OrderCar(
      id: 500 + id,
      brand: 'Toyota',
      model: 'RAV4',
      year: 2019,
      vinMasked: '··· L98111',
      mileageKm: 67000,
    ),
    verdict: InspectionVerdict.recommended,
    verdictComment: 'Кузов в родной краске',
    completedAt: DateTime.now().subtract(Duration(days: daysAgo)),
    city: 'Москва',
  );

  AuthService signedIn(int id) => AuthService()
    ..debugSetToken('t')
    ..debugSetUser(CurrentUser(id: id, name: 'Тест', email: 't@example.com'));

  Future<MockOrderRepository> pump(
    WidgetTester tester, {
    List<LibraryInspection> library = const [],
    int viewerId = 10,
  }) async {
    final repo = MockOrderRepository(orders: [order])..library = [...library];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: OrderDetailScreen(
          store: OrderStore(
            repo,
            catalog: MockCarCatalogRepository(),
            cities: MockCityRepository(),
          ),
          orderId: order.id,
          viewerIsCustomer: viewerId != 10,
          auth: signedIn(viewerId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  test('кандидат из библиотеки разбирается с датой осмотра', () {
    final car = OrderCar.fromJson({
      'id': 63,
      'brand': 'Toyota',
      'model': 'RAV4',
      'year': 2019,
      'vin_masked': '··· L98111',
      'from_library': true,
      'inspection': {
        'id': 40,
        'status': 'completed',
        'completed_at': '2026-11-05T08:24:48.000000Z',
        'verdict': 'recommended',
      },
    });
    expect(car.fromLibrary, isTrue);
    expect(
      car.inspectionCompletedAt!.isAtSameMomentAs(
        DateTime.utc(2026, 11, 5, 8, 24, 48),
      ),
      isTrue,
    );
    // в местное время: «сегодня/вчера» считаются по часам телефона
    expect(car.inspectionCompletedAt!.isUtc, isFalse);
    // правка телефона не теряет пометку
    expect(car.withSellerPhone('+79001112233').fromLibrary, isTrue);

    final plain = OrderCar.fromJson({
      'id': 1,
      'brand': 'Kia',
      'model': 'Rio',
      'year': 2019,
      'vin_masked': '—',
    });
    expect(plain.fromLibrary, isFalse);
    expect(plain.inspectionCompletedAt, isNull);
  });

  test('ответ библиотеки разбирается вместе со сроком', () {
    final page = InspectionLibraryPage.fromJson({
      'data': [
        {
          'inspection': {
            'id': 40,
            'verdict': 'with_reservations',
            'verdict_comment': null,
            'completed_at': '2026-11-05T08:24:48.000000Z',
          },
          'car': {
            'id': 63,
            'brand': 'Toyota',
            'model': 'RAV4',
            'year': 2019,
            'vin_masked': '··· L98111',
            'mileage_km': 67000,
          },
          'city': 'Москва',
        },
      ],
      'days': 30,
    });
    expect(page.days, 30);
    expect(page.items.single.inspectionId, 40);
    expect(page.items.single.verdict, InspectionVerdict.withReservations);
    expect(page.items.single.car.mileageKm, 67000);
    expect(page.items.single.city, 'Москва');
  });

  test('давность осмотра — по календарным дням', () {
    final now = DateTime.now();
    expect(inspectedAgo(now), 'осмотрена сегодня');
    expect(
      inspectedAgo(now.subtract(const Duration(days: 1))),
      'осмотрена вчера',
    );
    expect(
      inspectedAgo(now.subtract(const Duration(days: 2))),
      'осмотрена 2 дня назад',
    );
    expect(
      inspectedAgo(now.subtract(const Duration(days: 5))),
      'осмотрена 5 дней назад',
    );
    expect(
      inspectedAgo(now.subtract(const Duration(days: 21))),
      'осмотрена 21 день назад',
    );
  });

  testWidgets('пустая библиотека — кнопки нет', (tester) async {
    await pump(tester);
    expect(find.text('Осмотреть новый вариант'), findsOneWidget);
    expect(find.textContaining('Из моих осмотров'), findsNothing);
  });

  testWidgets('заказчику кнопки нет', (tester) async {
    await pump(tester, library: [item()], viewerId: 1);
    expect(find.textContaining('Из моих осмотров'), findsNothing);
  });

  testWidgets('осмотр из библиотеки — кандидатом после подтверждения', (
    tester,
  ) async {
    final repo = await pump(tester, library: [item()]);

    await tester.ensureVisible(find.text('Из моих осмотров · 1'));
    await tester.tap(find.text('Из моих осмотров · 1'));
    await tester.pumpAndSettle();
    expect(find.text('Toyota RAV4 2019'), findsOneWidget);
    expect(find.text('осмотрена 5 дней назад · Москва'), findsOneWidget);
    expect(find.text('67 000 км · ··· L98111'), findsOneWidget);

    await tester.tap(find.text('Toyota RAV4 2019'));
    await tester.pumpAndSettle();
    expect(find.text('Машина ещё продаётся?'), findsOneWidget);

    await tester.tap(find.text('Да, добавить'));
    await tester.pumpAndSettle();

    expect(repo.lastAttachedInspectionId, 77);
    expect(find.text('Кандидат добавлен'), findsOneWidget);
    // кандидат в списке с давностью осмотра, библиотека опустела
    expect(find.text('Toyota RAV4 2019'), findsOneWidget);
    expect(find.text('осмотрена 5 дней назад'), findsOneWidget);
    expect(find.textContaining('Из моих осмотров'), findsNothing);
    final updated = await repo.fetchOrder(order.id);
    expect(updated.status, OrderStatus.inspecting);
    expect(updated.cars.single.fromLibrary, isTrue);
  });

  testWidgets('«Отмена» в подтверждении ничего не прикрепляет', (
    tester,
  ) async {
    final repo = await pump(tester, library: [item()]);

    await tester.ensureVisible(find.text('Из моих осмотров · 1'));
    await tester.tap(find.text('Из моих осмотров · 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toyota RAV4 2019'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(repo.lastAttachedInspectionId, isNull);
    expect((await repo.fetchOrder(order.id)).cars, isEmpty);
    expect(find.text('Из моих осмотров · 1'), findsOneWidget);
  });
}
