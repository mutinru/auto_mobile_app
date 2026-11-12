import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:auto_podbor_mobile/data/api_client.dart';
import 'package:auto_podbor_mobile/data/api_order_repository.dart';
import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/json_list.dart';
import 'package:auto_podbor_mobile/models/current_user.dart';
import 'package:auto_podbor_mobile/models/order.dart';

/// Один битый элемент не роняет весь список (ревью №35).
void main() {
  Map<String, dynamic> order(Object? id) => {
    'id': id,
    'status': 'awaiting_executor',
    'brand': 'Kia',
    'model': 'Rio',
    'customer': {'id': 1, 'name': 'А'},
  };

  test('битый элемент пропускается, остальные разобраны', () {
    final orders = parseList(
      [order(1), order(null), order(3)],
      Order.fromJson,
      what: 'заказ',
    );

    expect([for (final o in orders) o.id], [1, 3]);
  });

  test('не список — пусто, без исключения', () {
    expect(parseList(null, Order.fromJson, what: 'заказ'), isEmpty);
    expect(parseList({'a': 1}, Order.fromJson, what: 'заказ'), isEmpty);
    expect(parseList(['строка'], Order.fromJson, what: 'заказ'), isEmpty);
  });

  test('«Мои заказы» с одним битым заказом показывают остальные', () async {
    final auth = AuthService()
      ..debugSetToken('t')
      ..debugSetUser(const CurrentUser(id: 1, name: 'А'));
    final orders = await http.runWithClient(
      () => ApiOrderRepository(ApiClient(auth)).fetchMyOrders(),
      () => MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': [order(1), order('сломан'), order(3)],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    expect([for (final o in orders) o.id], [1, 3]);
  });

  test('профиль без почты разбирается: вход по телефону', () {
    final user = CurrentUser.fromJson({
      'id': 7,
      'name': 'Максим',
      'email': null,
      'phone': '+79000000001',
    });
    expect(user.email, isNull);
    expect(user.phone, '+79000000001');

    expect(
      CurrentUser.fromJson({'id': 7, 'name': 'Максим'}).email,
      isNull,
    );
  });
}
