import 'package:flutter/material.dart';

import 'data/api_client.dart';
import 'data/api_order_repository.dart';
import 'data/api_verification_repository.dart';
import 'data/auth_service.dart';
import 'models/order.dart';
import 'models/order_kind.dart';
import 'screens/intent_screen.dart';
import 'screens/my_orders_screen.dart';
import 'screens/nearby_orders_screen.dart';
import 'screens/new_inspection_screen.dart';
import 'screens/new_order_screen.dart';
import 'screens/phone_login_screen.dart';
import 'screens/public_feed_screen.dart';
import 'screens/profile_screen.dart';
import 'state/order_store.dart';
import 'theme/app_theme.dart';
import 'widgets/order_kind_sheet.dart';

void main() {
  runApp(const AutoPodborApp());
}

class AutoPodborApp extends StatelessWidget {
  const AutoPodborApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auto Podbor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const _RootGate(),
    );
  }
}

/// Стартовый экран для всех — вопрос о намерении ([IntentScreen], кадр 01
/// макета car-storefront-modes.html), за ним экран выбранного режима:
/// «Ищу автомобиль» → [MyOrdersScreen], «Беру заказы» → [NearbyOrdersScreen],
/// «Просто посмотрю» → [PublicFeedScreen]. Первые два требуют токен, поэтому
/// гостя ведут через вход. Держит [AuthService] и отдаёт [OrderStore] на
/// реальном API в профиль.
///
/// Экраны одиночного осмотра (InspectionOverviewScreen) остаются
/// самостоятельным модулем — из этого хаба пока не достижимы напрямую,
/// подключаются к заказу отдельным проходом (см. "Старт осмотра" в макете).
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    // пробуем поднять прошлую сессию с диска
    _auth.restore().then((_) {
      if (mounted) setState(() {});
    });
  }

  /// Витрина открывается поверх вопроса о намерении, а не вместо него:
  /// «назад» с витрины возвращает к вопросу, а не закрывает приложение.
  void _openFeed() {
    Navigator.of(context).push(_feedRoute());
  }

  Route<void> _feedRoute() => MaterialPageRoute(
        builder: (_) => PublicFeedScreen(
          onPlaceOrder: _placeOrder,
          onRepeatSelection: () => _startOrder(OrderKind.selection),
        ),
      );

  /// «Ищу автомобиль» ведёт в мои заказы. /orders/mine требует токен, а
  /// экран на ошибке загрузки висит на спиннере — поэтому гостя сначала
  /// проводим через вход.
  void _openMyOrders() {
    if (_auth.isAuthenticated) {
      Navigator.of(context).push(_myOrdersRoute());
    } else {
      // вход открыт с вопроса о намерении, а не с витрины: «без входа»
      // подменяем витриной, чтобы «назад» с неё вёл к вопросу
      _pushLogin(
        then: _myOrdersRoute,
        onBrowse: () => Navigator.of(context).pushReplacement(_feedRoute()),
      );
    }
  }

  /// «Беру заказы на подбор» ведёт в «Заказы рядом». /orders/available
  /// требует токен, поэтому гостя, как и в «Ищу автомобиль», сначала
  /// проводим через вход, а «без входа» подменяем витриной.
  void _openNearbyOrders() {
    if (_auth.isAuthenticated) {
      Navigator.of(context).push(_nearbyOrdersRoute());
    } else {
      _pushLogin(
        then: _nearbyOrdersRoute,
        onBrowse: () => Navigator.of(context).pushReplacement(_feedRoute()),
      );
    }
  }

  /// «Разместить заказ» на витрине — тот же лист «подбор / осмотр»,
  /// что и «Новый заказ» в «Моих заказах».
  Future<void> _placeOrder() async {
    final kind = await showOrderKindSheet(context);
    if (kind != null && mounted) _startOrder(kind);
  }

  /// Форма заказа нужного вида. Создание требует токен, поэтому гостя
  /// сначала ведём через вход, а экран входа подменяем формой. «Без входа»
  /// возвращает на витрину, с которой пришли.
  void _startOrder(OrderKind kind) {
    if (_auth.isAuthenticated) {
      _openOrderForm(kind);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhoneLoginScreen(
          auth: _auth,
          onLoggedIn: () => _openOrderForm(kind, replace: true),
          onBrowse: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  /// Форма возвращает созданный заказ — тогда открываем «Мои заказы» на том
  /// же сторе, чтобы новый заказ был виден сразу. «Назад» из формы без
  /// отправки просто возвращает на витрину.
  Future<void> _openOrderForm(OrderKind kind, {bool replace = false}) async {
    final store = _orderStore();
    final navigator = Navigator.of(context);
    final route = MaterialPageRoute<Order>(
      builder: (_) => kind.isInspection
          ? NewInspectionScreen(store: store)
          : NewOrderScreen(store: store),
    );
    final created = replace
        ? await navigator.pushReplacement<Order, void>(route)
        : await navigator.push(route);
    if (created != null && mounted) {
      navigator.push(_myOrdersRoute(store));
    }
  }

  /// После входа сразу открываем экран [then] — гость нажимал кнопку ради
  /// действия, возвращать его назад значит терять этот шаг. Экран входа
  /// подменяем, чтобы «назад» с [then] не возвращал на вход.
  void _pushLogin({
    required Route<void> Function() then,
    required VoidCallback onBrowse,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhoneLoginScreen(
          auth: _auth,
          onLoggedIn: () => Navigator.of(context).pushReplacement(then()),
          onBrowse: onBrowse,
        ),
      ),
    );
  }

  OrderStore _orderStore() => OrderStore(ApiOrderRepository(ApiClient(_auth)));

  Route<void> _profileRoute() => MaterialPageRoute(
        builder: (_) => ProfileScreen(auth: _auth, store: _orderStore()),
      );

  Route<void> _myOrdersRoute([OrderStore? store]) => MaterialPageRoute(
        builder: (_) => MyOrdersScreen(
          auth: _auth,
          store: store ?? _orderStore(),
          // «Мои заказы» открываются только вошедшему — сразу в профиль
          onProfile: () => Navigator.of(context).push(_profileRoute()),
        ),
      );

  Route<void> _nearbyOrdersRoute() => MaterialPageRoute(
        builder: (_) => NearbyOrdersScreen(
          store: _orderStore(),
          verification: ApiVerificationRepository(ApiClient(_auth)),
          auth: _auth,
        ),
      );

  @override
  Widget build(BuildContext context) {
    // пока читаем токен — держим заставку, иначе витрина успеет
    // отрисоваться с гостевым состоянием кнопки
    if (_auth.isRestoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // вопрос о намерении — корень стека, показывается при каждом запуске,
    // выбор нигде не сохраняется. «Ищу автомобиль» ведёт в мои заказы,
    // «Беру заказы» — в «Заказы рядом», «Просто посмотрю» — на витрину
    return IntentScreen(
      onChoose: (intent) => switch (intent) {
        AppIntent.buy => _openMyOrders(),
        AppIntent.work => _openNearbyOrders(),
        AppIntent.browse => _openFeed(),
      },
    );
  }
}
