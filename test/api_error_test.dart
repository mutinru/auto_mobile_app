import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/api_exception.dart';
import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/screens/my_orders_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/api_error.dart';

/// Сервер отказывает во всех списках — проверяем, что пользователь видит
/// причину, а не сырой `ApiException(403): {json}`.
class _FailingRepository extends MockOrderRepository {
  _FailingRepository(this.error);

  final Object error;

  @override
  Future<List<Order>> fetchMyOrders() async => throw error;

  @override
  Future<List<Order>> fetchAssignedOrders() async => throw error;

  @override
  Future<List<Order>> fetchAvailableOrders() async => throw error;
}

void main() {
  OrderStore store(Object error) =>
      OrderStore(_FailingRepository(error), catalog: MockCarCatalogRepository(), cities: MockCityRepository());

  group('apiErrorText', () {
    test('причина от сервера — из message или первой ошибки поля', () {
      expect(apiErrorText(ApiException(422, '{"message":"Срок осмотра истёк"}')), 'Срок осмотра истёк');
      expect(
        apiErrorText(ApiException(422, '{"message":"x","errors":{"price":["Укажите цену"]}}')),
        'Укажите цену',
      );
      expect(apiErrorText(ApiException(403, '{"message":"Нет доступа"}')), 'Нет доступа');
    });

    test('служебные ответы и обрыв связи — понятной фразой', () {
      expect(apiErrorText(ApiException(429, '{"message":"Too Many Attempts."}')), startsWith('Слишком много запросов'));
      expect(apiErrorText(ApiException(500, '<html>')), 'Ошибка на сервере, попробуйте позже');
      expect(apiErrorText(Exception('Connection refused')), 'Нет связи с сервером');
    });
  });

  test('ошибки списков в сторе — текстом для пользователя', () async {
    final s = store(ApiException(403, '{"message":"Нет доступа"}'));
    await s.loadMyOrders();
    await s.loadAssignedOrders();
    await s.loadAvailableOrders();

    expect(s.mineError, 'Нет доступа');
    expect(s.assignedError, 'Нет доступа');
    expect(s.availableError, 'Нет доступа');
  });

  testWidgets('«Мои заказы» без связи — без сырого исключения', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: MyOrdersScreen(store: store(Exception('ClientException: Connection refused'))),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Нет связи с сервером'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });
}
