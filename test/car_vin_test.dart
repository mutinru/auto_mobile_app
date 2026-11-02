import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/api_exception.dart';
import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/inspection_type.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_car.dart';
import 'package:auto_podbor_mobile/models/vin_kind.dart';
import 'package:auto_podbor_mobile/screens/assigned_inspection_screen.dart';
import 'package:auto_podbor_mobile/screens/car_vin_screen.dart';
import 'package:auto_podbor_mobile/screens/inspection_order_detail_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/vin_capture.dart';

/// Сервер отклоняет фото таблички — ошибка должна лечь под блок VIN.
class _RejectingPhoto extends MockOrderRepository {
  @override
  Future<int> startInspection(
    int orderId,
    int carId, {
    InspectionType type = InspectionType.full,
    CapturedVin? vin,
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
  OrderStore store(MockOrderRepository repo) => OrderStore(
    repo,
    catalog: MockCarCatalogRepository(),
    cities: MockCityRepository(),
  );

  Future<Order> order2051() => MockOrderRepository().fetchOrder(2051);

  Future<int?> open(
    WidgetTester tester,
    MockOrderRepository repo,
    VinCaptureController vin,
  ) async {
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
                  builder: (_) =>
                      CarVinScreen(repository: repo, order: order, vin: vin),
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

      expect(find.text('Табличка VIN'), findsOneWidget);
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

    expect(find.text('Табличка VIN'), findsNothing);
    expect(repo.lastVin?.value, 'XW8ZZZ61ZKG100111');
    expect(repo.lastVin?.kind, VinKind.vin);
  });

  testWidgets('ошибка сервера по фото — под блоком VIN', (tester) async {
    final vin = VinCaptureController()..setPhoto('/tmp/plate.jpg');
    vin.text.text = 'XW8ZZZ61ZKG100111';
    await open(tester, _RejectingPhoto(), vin);

    await tester.tap(find.text('Начать осмотр'));
    await tester.pumpAndSettle();

    expect(find.text('Нужна фотография таблички'), findsOneWidget);
    expect(find.text('Табличка VIN'), findsOneWidget);
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
