import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/data/mock_verification_repository.dart';
import 'package:auto_podbor_mobile/data/profile_repository.dart';
import 'package:auto_podbor_mobile/models/nearby_filter.dart';
import 'package:auto_podbor_mobile/models/current_user.dart';
import 'package:auto_podbor_mobile/models/order_alerts.dart';
import 'package:auto_podbor_mobile/models/order_kind.dart';
import 'package:auto_podbor_mobile/models/push_target.dart';
import 'package:auto_podbor_mobile/screens/nearby_orders_screen.dart';
import 'package:auto_podbor_mobile/screens/settings_screen.dart';
import 'package:auto_podbor_mobile/state/nearby_filter_store.dart';
import 'package:auto_podbor_mobile/state/verification_status.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/order_alerts_prompt.dart';
import 'package:auto_podbor_mobile/widgets/order_alerts_sheet.dart';

import 'support/stores.dart';

/// Сессия без сети; сохранённые подписки — в [saved].
class _FakeAuth extends AuthService {
  _FakeAuth(OrderAlerts alerts) {
    debugSetUser(userWith(alerts));
  }

  final saved = <OrderAlerts>[];

  static CurrentUser userWith(OrderAlerts alerts) => CurrentUser(
    id: 3,
    name: 'Игорь В.',
    email: '+79000000003',
    orderAlerts: alerts,
  );
}

/// Профиль без сети ([ProfileRepository.factory]): сохранение подписки
/// пишется в [_FakeAuth.saved] и сразу подменяет профиль — как ответ сервера.
class _FakeProfile extends ProfileRepository {
  _FakeProfile(this._fake) : super(_fake);

  final _FakeAuth _fake;

  @override
  Future<void> updateOrderAlerts(OrderAlerts alerts) async {
    _fake.saved.add(alerts);
    _fake.debugSetUser(_FakeAuth.userWith(alerts));
  }
}

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(body: child),
);

void main() {
  setUp(() {
    ProfileRepository.factory = (auth) => _FakeProfile(auth as _FakeAuth);
  });
  tearDown(() => ProfileRepository.factory = ProfileRepository.new);

  group('OrderAlerts', () {
    test('разбор профиля и подпись', () {
      final user = CurrentUser.fromJson({
        'id': 1,
        'name': 'Игорь',
        'email': 'a@b.c',
        'order_alerts': {
          'cities': ['Москва', 'Казань'],
          'kinds': ['inspection'],
        },
      });
      final alerts = user.orderAlerts;
      expect(alerts.cities, {'Москва', 'Казань'});
      expect(alerts.kinds, {OrderKind.inspection});
      expect(alerts.isOn, isTrue);
      expect(alerts.summary, 'Казань, Москва · только осмотры');
      expect(alerts.toJson(), {
        'cities': ['Казань', 'Москва'],
        'kinds': ['inspection'],
      });
    });

    test('нет поля — выключена, оба вида', () {
      final user = CurrentUser.fromJson({
        'id': 1,
        'name': 'Игорь',
        'email': 'a@b.c',
      });
      expect(user.orderAlerts.isOn, isFalse);
      expect(user.orderAlerts.kinds, OrderKind.values.toSet());
      expect(user.orderAlerts.summary, 'Выключено');
    });
  });

  test('пуш о новом заказе и сводка открывают «Заказы рядом»', () {
    expect(
      PushTarget.fromData({
        'type': 'new_order',
        'order_id': '7',
        'order_kind': 'inspection',
      }),
      isA<NearbyOrdersTarget>(),
    );
    expect(
      PushTarget.fromData({'type': 'new_orders'}),
      isA<NearbyOrdersTarget>(),
    );
  });

  testWidgets('шторка: снять город и вид, последний вид не снимается', (
    tester,
  ) async {
    final auth = _FakeAuth(
      const OrderAlerts(cities: {'Казань', 'Москва'}),
    );
    await tester.pumpWidget(_app(OrderAlertsSheet(auth: auth)));

    await tester.tap(find.text('Москва  ✕'));
    await tester.tap(find.text('Подборы'));
    // осмотры — последний вид: снять нельзя
    await tester.tap(find.text('Осмотры'));
    await tester.pump();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(auth.saved.single.cities, {'Казань'});
    expect(auth.saved.single.kinds, {OrderKind.inspection});
  });

  testWidgets('карточка в ленте подписывает на город одним тапом', (
    tester,
  ) async {
    final auth = _FakeAuth(const OrderAlerts(cities: {'Москва'}));
    await tester.pumpWidget(
      _app(
        OrderAlertsPrompt(
          auth: auth,
          cities: const {'Казань'},
          emptyFeed: true,
          onConfigure: () {},
        ),
      ),
    );
    expect(find.text('Сообщать о новых заказах'), findsOneWidget);

    await tester.tap(find.text('Включить'));
    await tester.pumpAndSettle();

    expect(auth.saved.single.cities, {'Москва', 'Казань'});
    // город уже в подписке — вместо карточки строка о пуше
    expect(find.text('Сообщать о новых заказах'), findsNothing);
    expect(
      find.text('Пришлём пуш, когда появится заказ · Настроить'),
      findsOneWidget,
    );
  });

  testWidgets('в непустой ленте подписанный город карточку не показывает', (
    tester,
  ) async {
    final auth = _FakeAuth(const OrderAlerts(cities: {'Казань'}));
    await tester.pumpWidget(
      _app(
        OrderAlertsPrompt(
          auth: auth,
          cities: const {'Казань'},
          onConfigure: () {},
        ),
      ),
    );
    expect(find.text('Сообщать о новых заказах'), findsNothing);
    expect(find.textContaining('Пришлём пуш'), findsNothing);
  });

  testWidgets('настройки: строка подписки открывает шторку', (tester) async {
    final auth = _FakeAuth(const OrderAlerts(cities: {'Казань'}));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: SettingsScreen(auth: auth),
      ),
    );
    expect(find.text('Пуш о новых заказах'), findsOneWidget);
    expect(find.text('Казань'), findsOneWidget);

    await tester.tap(find.text('Пуш о новых заказах'));
    await tester.pumpAndSettle();
    expect(find.text('Новые заказы рядом'), findsWidgets);
    expect(find.text('Казань  ✕'), findsOneWidget);
  });

  group('чип подписки в «Заказы рядом»', () {
    Finder inSheet(String text) => find.descendant(
      of: find.byType(OrderAlertsSheet),
      matching: find.text(text),
    );

    Future<void> pumpFeed(WidgetTester tester, _FakeAuth auth) async {
      final filters = NearbyFilterStore();
      await filters.set(const NearbyFilter(cities: {'Казань'}));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: NearbyOrdersScreen(
            store: mockStore(
              orders: MockOrderRepository(),
            ),
            verification: VerificationStatus(
              MockVerificationRepository(passed: 4, required: false),
            ),
            auth: auth,
            filters: filters,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('выключена — «Сообщать о новых», шторка с городом фильтра', (
      tester,
    ) async {
      final auth = _FakeAuth(const OrderAlerts());
      await pumpFeed(tester, auth);

      expect(find.text('Сообщать о новых'), findsOneWidget);
      await tester.tap(find.text('Сообщать о новых'));
      await tester.pumpAndSettle();
      // город фильтра подставлен, но сохранится только по кнопке
      expect(inSheet('Казань  ✕'), findsOneWidget);
      expect(auth.saved, isEmpty);

      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(auth.saved.single.cities, {'Казань'});
      expect(find.text('Уведомления'), findsOneWidget);
    });

    testWidgets('включена — «Уведомления», шторка с подпиской', (
      tester,
    ) async {
      final auth = _FakeAuth(const OrderAlerts(cities: {'Москва'}));
      await pumpFeed(tester, auth);

      await tester.tap(find.text('Уведомления'));
      await tester.pumpAndSettle();
      expect(inSheet('Москва  ✕'), findsOneWidget);
      expect(inSheet('Казань  ✕'), findsNothing);
    });
  });
}
