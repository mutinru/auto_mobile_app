import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/current_user.dart';
import 'package:auto_podbor_mobile/models/order_car.dart';
import 'package:auto_podbor_mobile/models/order_kind.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/models/vin_kind.dart';
import 'package:auto_podbor_mobile/screens/order_detail_screen.dart';
import 'package:auto_podbor_mobile/screens/start_inspection_screen.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/odometer_capture.dart';
import 'package:auto_podbor_mobile/widgets/phone_input.dart';
import 'package:auto_podbor_mobile/widgets/vin_capture.dart';

import 'support/stores.dart';

/// Мок, который считает добавленные машины: форма с ошибками не должна
/// ничего отправлять.
class _CountingRepository extends MockOrderRepository {
  int added = 0;

  /// У подбора отдельного старта нет — экран не должен его звать.
  int started = 0;

  @override
  Future<int> startInspection(
    int orderId,
    int carId, {
    required CapturedVin vin,
    required CapturedOdometer odometer,
  }) {
    started++;
    return super.startInspection(orderId, carId, vin: vin, odometer: odometer);
  }

  @override
  Future<OrderCar> addCar(
    int orderId, {
    required String brand,
    required String model,
    required int year,
    required CapturedVin vin,
    required CapturedOdometer odometer,
    String? licensePlate,
    String? sellerPhone,
  }) {
    added++;
    return super.addCar(
      orderId,
      brand: brand,
      model: model,
      year: year,
      vin: vin,
      odometer: odometer,
      licensePlate: licensePlate,
      sellerPhone: sellerPhone,
    );
  }
}

/// Сервер успел завести кандидата, а ответ до клиента не дошёл: заказ
/// после этого отдаётся уже с машиной.
class _LostAnswerRepository extends MockOrderRepository {
  _LostAnswerRepository(this.order) : super(orders: [order]);

  Order order;

  @override
  Future<Order> fetchOrder(int id) async =>
      MockOrderRepository.withActions(order);
}

/// «Начать осмотр» в подборе: обязательность видна, ошибки — все сразу.
void main() {
  const order = Order(
    id: 37,
    kind: OrderKind.selection,
    status: OrderStatus.sourcing,
    brand: 'Kia',
    model: 'Sportage',
    yearFrom: 2020,
    customer: UserSummary(id: 6, name: 'Сергей П.'),
  );

  Future<_CountingRepository> open(
    WidgetTester tester, [
    VinCaptureController? vin,
    OdometerCaptureController? odometer,
  ]) async {
    // экран телефона: блок VIN высокий, в 800×600 год уезжает за край
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final repo = _CountingRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: StartInspectionScreen(
          repository: repo,
          catalog: MockCarCatalogRepository(),
          order: order,
          vin: vin,
          odometer: odometer,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> start(WidgetTester tester) async {
    await tester.tap(find.text('Начать осмотр'));
    await tester.pump();
  }

  testWidgets('пустая форма — все ошибки сразу, ничего не отправлено', (
    tester,
  ) async {
    final repo = await open(tester);
    await start(tester);

    expect(find.text('Укажите VIN'), findsOneWidget);
    expect(find.text('Укажите пробег по одометру'), findsOneWidget);
    expect(find.text('Укажите год выпуска'), findsOneWidget);
    // марка и модель подставлены из заказа — к ним претензий нет
    expect(find.text('Выберите марку и модель'), findsNothing);
    expect(repo.added, 0);
  });

  testWidgets('правка поля убирает только его ошибку', (tester) async {
    await open(tester);
    await start(tester);

    // поля ввода по порядку: пробег по одометру, госномер, год
    await tester.enterText(find.byType(TextField).at(0), '64000');
    await tester.pump();

    expect(find.text('Укажите пробег по одометру'), findsNothing);
    expect(find.text('Укажите год выпуска'), findsOneWidget);
    expect(find.text('Укажите VIN'), findsOneWidget);
  });

  testWidgets('год вне границ — своя ошибка у поля', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).at(2), '1985');
    await start(tester);

    expect(find.textContaining('Год — от 1990'), findsOneWidget);
  });

  testWidgets('без черновика; госномер необязателен; тип — только полный', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Сохранить как черновик'), findsNothing);
    expect(find.text('необязательно'), findsOneWidget);

    // «Экспресс» виден, но не выбирается
    await tester.scrollUntilVisible(
      find.text('Экспресс'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Экспресс'));
    await tester.pump();
    final full = tester.widget<Text>(find.text('Полный · 17 пунктов'));
    final express = tester.widget<Text>(find.text('Экспресс'));
    expect(full.style!.color, isNot(express.style!.color));
  });

  testWidgets('VIN без снимка таблички — ошибка, кандидат не заводится', (
    tester,
  ) async {
    final vin = VinCaptureController();
    final repo = await open(tester, vin);
    vin.text.text = 'XW8ZZZ61ZKG100111';
    await tester.enterText(find.byType(TextField).at(0), '64000');
    await tester.enterText(find.byType(TextField).at(2), '2020');
    await start(tester);

    expect(find.text('Сфотографируйте табличку'), findsOneWidget);
    expect(repo.added, 0);
  });

  testWidgets('со снимком VIN уходит на сервер вместе с фото', (tester) async {
    final vin = VinCaptureController()
      ..setKind(VinKind.bodyNumber)
      ..setPhoto('/tmp/plate.jpg');
    vin.text.text = 'gx110-6012345';
    final odometer = OdometerCaptureController()..setPhoto('/tmp/odo.jpg');
    final repo = await open(tester, vin, odometer);
    await tester.enterText(find.byType(TextField).at(0), '64000');
    await tester.enterText(find.byType(TextField).at(2), '2020');
    await start(tester);
    await tester.pumpAndSettle();

    expect(repo.added, 1);
    expect(repo.lastVin?.value, 'GX110-6012345');
    expect(repo.lastVin?.kind, VinKind.bodyNumber);
    expect(repo.lastVin?.photoPath, '/tmp/plate.jpg');
    expect(repo.lastOdometer?.km, 64000);
    expect(repo.lastOdometer?.photoPath, '/tmp/odo.jpg');
  });

  testWidgets('кандидат — одним запросом, экран отдаёт машину с осмотром', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final repo = _CountingRepository();
    final vin = VinCaptureController()..setPhoto('/tmp/plate.jpg');
    vin.text.text = 'XW8ZZZ61ZKG100111';
    final odometer = OdometerCaptureController()..setPhoto('/tmp/odo.jpg');
    OrderCar? result;

    // экран открыт поверх карточки — проверяем, с чем он закрылся
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<OrderCar>(
                MaterialPageRoute(
                  builder: (_) => StartInspectionScreen(
                    repository: repo,
                    catalog: MockCarCatalogRepository(),
                    order: order,
                    vin: vin,
                    odometer: odometer,
                  ),
                ),
              );
            },
            child: const Text('открыть'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('открыть'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '64000');
    await tester.enterText(find.byType(TextField).at(2), '2020');
    await start(tester);
    await tester.pumpAndSettle();

    expect(repo.added, 1);
    expect(repo.started, 0);
    expect(find.byType(StartInspectionScreen), findsNothing);
    expect(result, isNotNull);
    expect(result!.inspectionId, isNotNull);
    expect(result!.inspectionStatus, 'in_progress');
  });

  testWidgets('пробег без фото одометра — ошибка, кандидат не заводится', (
    tester,
  ) async {
    final vin = VinCaptureController()..setPhoto('/tmp/plate.jpg');
    vin.text.text = 'XW8ZZZ61ZKG100111';
    final repo = await open(tester, vin);
    await tester.enterText(find.byType(TextField).at(0), '64000');
    await tester.enterText(find.byType(TextField).at(2), '2020');
    await start(tester);

    expect(find.text('Сфотографируйте одометр'), findsOneWidget);
    expect(repo.added, 0);
  });

  testWidgets('вернулись с экрана кандидата без машины — карточка перечитана', (
    tester,
  ) async {
    const executor = UserSummary(id: 10, name: 'Максим К.');
    final sourcing = order.copyWith(executor: executor);
    final repo = _LostAnswerRepository(sourcing);
    final auth = AuthService()
      ..debugSetToken('t')
      ..debugSetUser(
        const CurrentUser(id: 10, name: 'Максим К.', email: 'm@example.com'),
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: OrderDetailScreen(
          store: mockStore(
            orders: repo,
          ),
          orderId: sourcing.id,
          viewerIsCustomer: false,
          auth: auth,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Sorento'), findsNothing);

    await tester.tap(find.text('Осмотреть новый вариант'));
    await tester.pumpAndSettle();
    expect(find.byType(StartInspectionScreen), findsOneWidget);

    repo.order = sourcing.copyWith(
      cars: const [
        OrderCar(
          id: 501,
          brand: 'Kia',
          model: 'Sorento',
          year: 2021,
          vinMasked: '—',
          inspectionId: 77,
          inspectionStatus: 'in_progress',
        ),
      ],
    );
    Navigator.of(tester.element(find.byType(StartInspectionScreen))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(StartInspectionScreen), findsNothing);
    expect(find.textContaining('Sorento'), findsWidgets);
  });

  Finder sellerPhone() => find.descendant(
    of: find.byType(PhoneField),
    matching: find.byType(TextField),
  );

  /// Поле продавца — в конце формы: ListView строит его, только докрутив.
  Future<void> typeSellerPhone(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      sellerPhone(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(sellerPhone(), text);
  }

  testWidgets('телефон продавца уходит на сервер как +7…', (tester) async {
    final vin = VinCaptureController()..setPhoto('/tmp/plate.jpg');
    vin.text.text = 'XW8ZZZ61ZKG100111';
    final odometer = OdometerCaptureController()..setPhoto('/tmp/odo.jpg');
    final repo = await open(tester, vin, odometer);
    await tester.enterText(find.byType(TextField).at(0), '64000');
    await tester.enterText(find.byType(TextField).at(2), '2020');
    await typeSellerPhone(tester, '9161234567');
    await start(tester);
    await tester.pumpAndSettle();

    expect(repo.added, 1);
    expect(repo.lastSellerPhone, '+79161234567');
  });

  testWidgets('без телефона продавца кандидат заводится, с неполным — нет', (
    tester,
  ) async {
    final vin = VinCaptureController()..setPhoto('/tmp/plate.jpg');
    vin.text.text = 'XW8ZZZ61ZKG100111';
    final odometer = OdometerCaptureController()..setPhoto('/tmp/odo.jpg');
    final repo = await open(tester, vin, odometer);
    await tester.enterText(find.byType(TextField).at(0), '64000');
    await tester.enterText(find.byType(TextField).at(2), '2020');
    await typeSellerPhone(tester, '91612');
    await start(tester);

    expect(find.text('Телефон продавца — 10 цифр после +7'), findsOneWidget);
    expect(repo.added, 0);

    await typeSellerPhone(tester, '');
    await start(tester);
    await tester.pumpAndSettle();
    expect(repo.added, 1);
    expect(repo.lastSellerPhone, isNull);
  });
}
