import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:auto_podbor_mobile/data/api_exception.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/available_page.dart';
import 'package:auto_podbor_mobile/models/nearby_filter.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/screens/my_orders_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/api_error.dart';

import 'support/stores.dart';

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
  Future<AvailablePage> fetchAvailableOrders({
    NearbyFilter filter = const NearbyFilter(),
    bool fewResponses = false,
    int page = 1,
  }) async => throw error;
}

void main() {
  OrderStore store(Object error) => mockStore(
    orders: _FailingRepository(error),
  );

  group('apiErrorText', () {
    test('причина от сервера — из message или первой ошибки поля', () {
      expect(
        apiErrorText(ApiException(422, '{"message":"Срок осмотра истёк"}')),
        'Срок осмотра истёк',
      );
      expect(
        apiErrorText(
          ApiException(
            422,
            '{"message":"x","errors":{"price":["Укажите цену"]}}',
          ),
        ),
        'Укажите цену',
      );
      expect(
        apiErrorText(ApiException(403, '{"message":"Нет доступа"}')),
        'Нет доступа',
      );
    });

    test('служебные ответы и обрыв связи — понятной фразой', () {
      expect(
        apiErrorText(ApiException(429, '{"message":"Too Many Attempts."}')),
        startsWith('Слишком много запросов'),
      );
      expect(
        apiErrorText(ApiException(500, '<html>')),
        'Ошибка на сервере, попробуйте позже',
      );
    });

    test('тело без причины (HTML nginx, пустое) — общей фразой', () {
      // 413 отвечает nginx до Laravel — разметку на экран не выводим
      expect(
        apiErrorText(ApiException(413, '<html><body>413</body></html>')),
        requestFailedText,
      );
      expect(apiErrorText(ApiException(404, '')), requestFailedText);
      expect(apiErrorText(ApiException(422, '{}')), requestFailedText);
      // а понятная причина — как есть
      expect(
        apiErrorText(ApiException(409, '{"message":"Уже оплачено"}')),
        'Уже оплачено',
      );
    });

    test('обрыв связи — «Нет связи», по типу исключения', () {
      for (final error in <Object>[
        http.ClientException('Connection refused'),
        const SocketException('Network is unreachable'),
        TimeoutException('нет ответа'),
      ]) {
        expect(apiErrorText(error), networkErrorText, reason: '$error');
        expect(isNetworkError(error), isTrue);
      }
    });

    test('ответ пришёл, но не разобран — не «Нет связи» (QA №1)', () {
      Object? typeError;
      try {
        // так падал разбор кандидата: год пришёл строкой
        final year = ('2019' as dynamic) as int;
        fail('ожидали TypeError, получили $year');
      } on TypeError catch (e) {
        typeError = e;
      }
      for (final error in <Object>[
        typeError,
        const FormatException('Unexpected character'),
        StateError('Bad state'),
      ]) {
        expect(apiErrorText(error), unexpectedErrorText, reason: '$error');
        expect(isNetworkError(error), isFalse);
      }
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
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MyOrdersScreen(
          store: store(http.ClientException('Connection refused')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(networkErrorText), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('«Мои заказы»: ответ не разобран — не «Нет связи»', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MyOrdersScreen(
          store: store(const FormatException('Unexpected character')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(unexpectedErrorText), findsOneWidget);
    expect(find.text(networkErrorText), findsNothing);
  });
}
