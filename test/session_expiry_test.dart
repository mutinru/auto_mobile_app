import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:auto_podbor_mobile/data/api_client.dart';
import 'package:auto_podbor_mobile/data/api_exception.dart';
import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/inspection_repository.dart';
import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_inspection_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/screens/inspection_report_screen.dart';
import 'package:auto_podbor_mobile/screens/order_detail_screen.dart';
import 'package:auto_podbor_mobile/state/inspection_store.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

/// Заказ не грузится — сеть, 500 или что угодно.
class _FailingOrders extends MockOrderRepository {
  @override
  Future<Order> fetchOrder(int id) async => throw ApiException(500, '<html>502 Bad Gateway</html>');
}

/// Осмотр не грузится.
class _FailingInspection extends MockInspectionRepository {
  @override
  Future<InspectionSnapshot> fetchInspection() async => throw ApiException(500, '{"message":"Server Error"}');
}

void main() {
  group('протухшая сессия', () {
    test('expireSession стирает токен один раз и ставит флаг', () {
      final auth = AuthService()..debugSetToken('t');
      var notified = 0;
      auth.addListener(() => notified++);

      auth.expireSession();
      // второй 401 от параллельного запроса — уже без токена, ничего не делает
      auth.expireSession();

      expect(auth.isAuthenticated, isFalse);
      expect(auth.sessionExpired, isTrue);
      expect(notified, 1);

      auth.consumeSessionExpired();
      expect(auth.sessionExpired, isFalse);
    });

    test('гость без токена сессию не «теряет»', () {
      final auth = AuthService();
      auth.expireSession();
      expect(auth.sessionExpired, isFalse);
    });

    test('ApiClient на 401 стирает сессию, на 500 — нет', () async {
      final auth = AuthService()..debugSetToken('t');
      final client = ApiClient(auth);

      await http.runWithClient(
        () => expectLater(client.get('/orders/mine'), throwsA(isA<ApiException>())),
        () => MockClient((_) async => http.Response('{"message":"Server Error"}', 500)),
      );
      expect(auth.isAuthenticated, isTrue);

      await http.runWithClient(
        () => expectLater(
          client.get('/orders/mine'),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
        ),
        () => MockClient((_) async => http.Response('{"message":"Unauthenticated."}', 401)),
      );
      expect(auth.isAuthenticated, isFalse);
      expect(auth.sessionExpired, isTrue);
    });
  });

  group('нет вечного спиннера', () {
    testWidgets('карточка подбора: ошибка и «Повторить» вместо спиннера', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: OrderDetailScreen(
          store: OrderStore(_FailingOrders(), catalog: MockCarCatalogRepository(), cities: MockCityRepository()),
          orderId: 2044,
          viewerIsCustomer: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Не удалось загрузить заказ'), findsOneWidget);
      // HTML-тело 502 наружу не попадает
      expect(find.text('Ошибка на сервере, попробуйте позже'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
    });

    testWidgets('отчёт осмотра: ошибка стора видна, без сырого ApiException', (tester) async {
      final order = await MockOrderRepository().fetchOrder(2047);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: InspectionReportScreen(store: InspectionStore(_FailingInspection()), order: order),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Не удалось загрузить отчёт'), findsOneWidget);
      expect(find.text('Ошибка на сервере, попробуйте позже'), findsOneWidget);
      expect(find.textContaining('ApiException'), findsNothing);
    });
  });
}
