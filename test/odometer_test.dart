import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_inspection_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_car.dart';
import 'package:auto_podbor_mobile/screens/inspection_order_detail_screen.dart';
import 'package:auto_podbor_mobile/screens/inspection_report_screen.dart';
import 'package:auto_podbor_mobile/state/inspection_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/app_ui.dart';
import 'package:auto_podbor_mobile/widgets/odometer_capture.dart';

import 'support/stores.dart';

/// Машина заказа 2047 с другим пробегом по одометру; флаг расхождения —
/// как его посчитал бы сервер.
class _Odometer extends MockOrderRepository {
  _Odometer({required this.km, required this.mismatch});

  final int km;
  final bool mismatch;

  @override
  Future<Order> fetchOrder(int id) async {
    final order = await super.fetchOrder(id);
    final car = order.cars.first;
    return order.copyWith(
      cars: [
        OrderCar(
          id: car.id,
          brand: car.brand,
          model: car.model,
          year: car.year,
          vinMasked: car.vinMasked,
          mileageKm: km,
          customerMileageKm: car.customerMileageKm,
          mileageMismatch: mismatch,
          inspectionId: car.inspectionId,
          inspectionStatus: car.inspectionStatus,
          verdict: car.verdict,
          verdictComment: car.verdictComment,
        ),
      ],
    );
  }
}

/// Пробег по одометру от исполнителя: «заявлено / по факту» у заказчика.
void main() {
  Future<void> openOrder(
    WidgetTester tester,
    MockOrderRepository repo,
    int id, {
    bool customer = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: InspectionOrderDetailScreen(
          store: mockStore(
            orders: repo,
          ),
          orderId: id,
          viewerIsCustomer: customer,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('без цифры и без фото одометра — свои ошибки', () {
    final c = OdometerCaptureController();
    expect(c.validate(), isNull);
    expect(c.error, 'Укажите пробег по одометру');

    c.text.text = '148000';
    expect(c.error, isNull);
    expect(c.validate(), isNull);
    expect(c.error, 'Сфотографируйте одометр');

    c.setPhoto('/tmp/odo.jpg');
    final odometer = c.validate();
    expect(odometer?.km, 148000);
    expect(odometer?.photoPath, '/tmp/odo.jpg');
  });

  test('одометр за потолком сервера — ошибка у цифр (QA №19)', () {
    final c = OdometerCaptureController()..setPhoto('/tmp/odo.jpg');
    c.text.text = '2000001';
    expect(c.validate(), isNull);
    expect(c.error, 'Пробег — не больше 2 000 000 км');

    c.text.text = '2000000';
    expect(c.validate()?.km, 2000000);
  });

  testWidgets('ошибка потолка стоит у поля, а не под блоком', (tester) async {
    final c = OdometerCaptureController()..setPhoto('/tmp/odo.jpg');
    c.text.text = '2500000';
    c.validate();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: OdometerCapture(controller: c)),
      ),
    );
    final field = tester.widget<FieldBoxInput>(find.byType(FieldBoxInput));
    expect(field.error, 'Пробег — не больше 2 000 000 км');
  });

  testWidgets('до осмотра — пробег со слов продавца', (tester) async {
    await openOrder(tester, MockOrderRepository(), 2051);

    expect(find.text('64 000 км · со слов продавца'), findsOneWidget);
    expect(find.textContaining('по одометру'), findsNothing);
  });

  testWidgets('после осмотра — по одометру и заявленный, плашка', (
    tester,
  ) async {
    await openOrder(tester, MockOrderRepository(), 2047);

    expect(
      find.text('98 000 км по одометру · заявлено 71 000'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'на 27 000 км больше заявленного',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('меньше заявленного — плашка про скрутку', (tester) async {
    await openOrder(tester, _Odometer(km: 50000, mismatch: true), 2047);

    expect(
      find.textContaining('скрутки одометра', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('малая разница — без плашки, порог решает сервер', (
    tester,
  ) async {
    await openOrder(tester, _Odometer(km: 73000, mismatch: false), 2047);

    expect(
      find.text('73 000 км по одометру · заявлено 71 000'),
      findsOneWidget,
    );
    expect(
      find.textContaining('заявленного', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('исполнитель плашку расхождения пробега не видит', (
    tester,
  ) async {
    await openOrder(tester, MockOrderRepository(), 2047, customer: false);

    expect(
      find.textContaining('заявленного', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('в отчёте блок пробега с заявленным и плашкой', (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final store = InspectionStore(MockInspectionRepository(), readOnly: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: InspectionReportScreen.purchased(
          store: store,
          title: 'Toyota Camry 2019',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ПРОБЕГ'), findsOneWidget);
    expect(find.text('127 450 км'), findsOneWidget);
    expect(find.textContaining('заявлено 120 000 км'), findsOneWidget);
    expect(
      find.textContaining(
        'на 7 450 км больше заявленного',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });
}
