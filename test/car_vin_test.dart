import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/api_exception.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_car.dart';
import 'package:auto_podbor_mobile/models/vin_kind.dart';
import 'package:auto_podbor_mobile/screens/assigned_inspection_screen.dart';
import 'package:auto_podbor_mobile/screens/car_vin_screen.dart';
import 'package:auto_podbor_mobile/screens/inspection_order_detail_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/odometer_capture.dart';
import 'package:auto_podbor_mobile/widgets/vin_capture.dart';

import 'support/stores.dart';

/// Сервер отклоняет фото таблички — ошибка должна лечь под блок VIN.
class _RejectingPhoto extends MockOrderRepository {
  @override
  Future<int> startInspection(
    int orderId,
    int carId, {
    required CapturedVin vin,
    required CapturedOdometer odometer,
  }) async => throw ApiException(
    422,
    '{"message":"x","errors":{"vin_photo":["Нужна фотография таблички"]}}',
  );
}

/// Заказ, где VIN исполнителя не совпал с VIN заказчика.
class _Mismatch extends MockOrderRepository {
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
          vinMasked: '··· 100111',
          vinMismatch: true,
        ),
      ],
    );
  }
}

/// Разовый осмотр начинается с таблички VIN — экран исполнителя.
void main() {
  OrderStore store(MockOrderRepository repo) => mockStore(
    orders: repo,
  );

  Future<Order> order2051() => MockOrderRepository().fetchOrder(2051);

  /// Одометр по умолчанию снят — тесты VIN проверяют свой блок.
  OdometerCaptureController shotOdometer() => OdometerCaptureController()
    ..setPhoto('/tmp/odo.jpg')
    ..text.text = '148000';

  Future<int?> open(
    WidgetTester tester,
    MockOrderRepository repo,
    VinCaptureController vin, [
    OdometerCaptureController? odometer,
  ]) async {
    // экран телефона: два блока съёмки не влезают в 800×600
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final odo = odometer ?? shotOdometer();
    final order = await order2051();
    int? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<int>(
                MaterialPageRoute(
                  builder: (_) => CarVinScreen(
                    repository: repo,
                    order: order,
                    vin: vin,
                    odometer: odo,
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
    return result;
  }

  testWidgets(
    '«Начать осмотр» ведёт на табличку, VIN заказчика не подставлен',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: AssignedInspectionScreen(
            store: store(MockOrderRepository()),
            orderId: 2051,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Начать осмотр'));
      await tester.pumpAndSettle();

      expect(find.text('VIN и пробег'), findsOneWidget);
      expect(find.text('нажмите, чтобы снять табличку'), findsOneWidget);
      expect(find.text('Kia Rio 2019'), findsOneWidget);
    },
  );

  testWidgets('без снимка осмотр не начинается', (tester) async {
    final repo = MockOrderRepository();
    final vin = VinCaptureController();
    await open(tester, repo, vin);
    vin.text.text = 'XW8ZZZ61ZKG100111';

    await tester.tap(find.text('Начать осмотр'));
    await tester.pumpAndSettle();

    expect(find.text('Сфотографируйте табличку'), findsOneWidget);
    expect(repo.lastVin, isNull);
  });

  testWidgets('VIN со снимком — осмотр начат, экран вернул его id', (
    tester,
  ) async {
    final repo = MockOrderRepository();
    final vin = VinCaptureController()..setPhoto('/tmp/plate.jpg');
    vin.text.text = 'xw8zzz61zkg100111';
    await open(tester, repo, vin);

    expect(find.text('Фото таблички сохранено'), findsOneWidget);
    await tester.tap(find.text('Начать осмотр'));
    await tester.pumpAndSettle();

    expect(find.text('VIN и пробег'), findsNothing);
    expect(repo.lastVin?.value, 'XW8ZZZ61ZKG100111');
    expect(repo.lastVin?.kind, VinKind.vin);
    expect(repo.lastOdometer?.km, 148000);
    expect(repo.lastOdometer?.photoPath, '/tmp/odo.jpg');
  });

  testWidgets('без фото одометра осмотр не начинается', (tester) async {
    final repo = MockOrderRepository();
    final vin = VinCaptureController()..setPhoto('/tmp/plate.jpg');
    vin.text.text = 'XW8ZZZ61ZKG100111';
    final odometer = OdometerCaptureController()..text.text = '148000';
    await open(tester, repo, vin, odometer);

    await tester.tap(find.text('Начать осмотр'));
    await tester.pumpAndSettle();

    expect(find.text('Сфотографируйте одометр'), findsOneWidget);
    expect(repo.lastVin, isNull);
    expect(repo.lastOdometer, isNull);
  });

  testWidgets('номер кузова — по ссылке «Нет VIN?», а не равным чипом', (
    tester,
  ) async {
    final vin = VinCaptureController();
    await open(tester, MockOrderRepository(), vin);

    expect(find.text('Номер кузова'), findsNothing);
    expect(find.text('Нет VIN? Указать номер кузова'), findsOneWidget);
    expect(
      find.text('у японских праворульных и части старых машин'),
      findsOneWidget,
    );

    vin.text.text = 'XW8ZZZ61ZKG100111';
    await tester.tap(find.text('Нет VIN? Указать номер кузова'));
    await tester.pumpAndSettle();

    expect(vin.kind, VinKind.bodyNumber);
    expect(find.text('НОМЕР КУЗОВА'), findsOneWidget);
    expect(find.text('нажмите, чтобы снять номер кузова'), findsOneWidget);
    // VIN под номер кузова не подходит — поле очищено
    expect(vin.value, isEmpty);

    await tester.tap(find.text('← Вернуться к VIN'));
    await tester.pumpAndSettle();
    expect(vin.kind, VinKind.vin);
    expect(find.text('Нет VIN? Указать номер кузова'), findsOneWidget);
  });

  testWidgets('ошибка сервера по фото — под блоком VIN', (tester) async {
    final vin = VinCaptureController()..setPhoto('/tmp/plate.jpg');
    vin.text.text = 'XW8ZZZ61ZKG100111';
    await open(tester, _RejectingPhoto(), vin);

    await tester.tap(find.text('Начать осмотр'));
    await tester.pumpAndSettle();

    expect(find.text('Нужна фотография таблички'), findsOneWidget);
    expect(find.text('VIN и пробег'), findsOneWidget);
  });

  testWidgets('заказчик видит, что VIN на машине другой', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: InspectionOrderDetailScreen(
          store: store(_Mismatch()),
          orderId: 2051,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('VIN на машине отличается от указанного вами'),
      findsOneWidget,
    );
  });

  testWidgets('исполнитель плашку расхождения не видит', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: InspectionOrderDetailScreen(
          store: store(_Mismatch()),
          orderId: 2051,
          viewerIsCustomer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('VIN на машине отличается'), findsNothing);
  });
}
