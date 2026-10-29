import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/api_client.dart';
import 'data/api_order_repository.dart';
import 'data/api_verification_repository.dart';
import 'data/auth_service.dart';
import 'data/car_catalog_repository.dart';
import 'data/city_repository.dart';
import 'data/location_service.dart';
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
import 'state/city_locator.dart';
import 'state/nearby_filter_store.dart';
import 'state/order_store.dart';
import 'state/support_chat_scope.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/order_kind_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // тему читаем до первого кадра, иначе светлая мигнёт тёмной
  final theme = ThemeController();
  await theme.load();
  runApp(AutoPodborApp(theme: theme, auth: AuthService()));
}

class AutoPodborApp extends StatelessWidget {
  const AutoPodborApp({super.key, required this.theme, required this.auth});

  final ThemeController theme;

  /// Одна сессия на приложение. Создаётся здесь, а не в _RootGate: чат
  /// поддержки открывается из шторки на любом маршруте, и SupportChatScope
  /// должен стоять выше Navigator.
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    // смена темы перестраивает только MaterialApp: стек маршрутов и
    // _RootGate с AuthService живут дальше, открытые экраны
    // перекрашиваются сами — они читают цвета через context.colors
    return ThemeScope(
      controller: theme,
      child: ListenableBuilder(
        listenable: theme,
        builder: (_, _) => MaterialApp(
          title: 'БитНеБит',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: theme.mode,
          // у экранов нет AppBar, поэтому иконки статус-бара красим здесь:
          // тёмные на светлой теме, светлые на тёмной
          builder: (context, child) => SupportChatScope(
            auth: auth,
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: theme.isLight
                  ? SystemUiOverlayStyle.dark
                  : SystemUiOverlayStyle.light,
              child: child!,
            ),
          ),
          home: _RootGate(auth: auth),
        ),
      ),
    );
  }
}

/// Стартовый экран для всех — вопрос о намерении ([IntentScreen], кадр 01
/// макета car-storefront-modes.html), за ним экран выбранного режима:
/// «Ищу автомобиль» → [MyOrdersScreen], «Беру заказы» → [NearbyOrdersScreen],
/// «Просто посмотрю» → [PublicFeedScreen]. Первые два требуют токен, поэтому
/// гостя ведут через вход. Выбранный раздел встаёт на место вопроса (см.
/// [_RootGateState._switchTo]), витрина — поверх него. Держит [AuthService]
/// и отдаёт [OrderStore] на реальном API в разделы.
///
/// Экраны одиночного осмотра (InspectionOverviewScreen) остаются
/// самостоятельным модулем — из этого хаба пока не достижимы напрямую,
/// подключаются к заказу отдельным проходом (см. "Старт осмотра" в макете).
class _RootGate extends StatefulWidget {
  const _RootGate({required this.auth});

  final AuthService auth;

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  late final _auth = widget.auth;

  /// Один на приложение: справочник кешируется на всю сессию, а сторы
  /// заказов создаются заново на каждый раздел.
  late final _carCatalog = ApiCarCatalogRepository(ApiClient(_auth));
  late final _cities = ApiCityRepository(ApiClient(_auth));
  late final _cityLocator = CityLocator(_cities, const GeolocatorLocationService());

  @override
  void initState() {
    super.initState();
    // пробуем поднять прошлую сессию с диска
    _auth.restore().then((_) {
      if (mounted) setState(() {});
    });
    _auth.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  /// Сервер ответил 401 — токен отозван или протух. Снимаем раздел и всё,
  /// что над ним, и ведём на вход; после входа возвращаем в тот же раздел.
  /// Без этого каждый экран показывал бы «Сессия истекла», а выйти из
  /// тупика можно было только переустановкой.
  void _onAuthChanged() {
    if (!_auth.sessionExpired || !mounted) return;
    _auth.consumeSessionExpired();
    final section = _section;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _root = null;
      _section = null;
    });
    messenger.showSnackBar(
      const SnackBar(content: Text('Сессия истекла — войдите заново')),
    );
    // гостю (витрина, вопрос о намерении) вход не навязываем
    if (section == null) return;
    _pushLogin(
      onLoggedIn: () => _switchTo(section),
      onBrowse: () => Navigator.of(context).pushReplacement(_feedRoute()),
    );
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
  void _openMyOrders() => _openSection(_Section.myOrders);

  /// «Беру заказы на подбор» ведёт в «Заказы рядом». /orders/available
  /// требует токен, поэтому гостя, как и в «Ищу автомобиль», сначала
  /// проводим через вход.
  void _openNearbyOrders() => _openSection(_Section.nearby);

  void _openSection(_Section section) {
    if (_auth.isAuthenticated) {
      _switchTo(section);
    } else {
      // вход открыт с вопроса о намерении, а не с витрины: «без входа»
      // подменяем витриной, чтобы «назад» с неё вёл к вопросу
      _pushLogin(
        onLoggedIn: () => _switchTo(section),
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
      _switchTo(_Section.myOrders, store: store);
    }
  }

  /// После входа сразу выполняем [onLoggedIn] — гость нажимал кнопку ради
  /// действия, возвращать его назад значит терять этот шаг.
  void _pushLogin({
    required VoidCallback onLoggedIn,
    required VoidCallback onBrowse,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhoneLoginScreen(
          auth: _auth,
          onLoggedIn: onLoggedIn,
          onBrowse: onBrowse,
        ),
      ),
    );
  }

  OrderStore _orderStore() =>
      OrderStore(
        ApiOrderRepository(ApiClient(_auth)),
        catalog: _carCatalog,
        cities: _cities,
        locator: _cityLocator,
      );

  /// Открытый раздел. null — показываем вопрос о намерении.
  Widget? _root;

  /// Какой раздел открыт — чтобы вернуть в него после повторного входа.
  _Section? _section;

  /// Переход в раздел «Мои заказы», «Заказы рядом» или «Профиль». Раздел
  /// встаёт в корень стека вместо вопроса о намерении (и вместо другого
  /// раздела), а всё, что было сверху — вход, витрина, форма, — снимается.
  /// Поэтому у раздела нет стрелки «назад», а системное «назад» закрывает
  /// приложение. Корневой маршрут не подменяем: вместе с ним умер бы
  /// _RootGateState, а колбэки открытых экранов зовут его контекст.
  void _switchTo(_Section section, {OrderStore? store}) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _section = section;
      _root = _sectionScreen(section, store: store);
    });
  }

  /// Выход: раздел снимается, снова виден вопрос о намерении. Сторы
  /// разделов создаются заново на каждый [_switchTo], поэтому данные
  /// прошлого пользователя выход не переживут.
  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _root = null;
      _section = null;
    });
  }

  /// Экран раздела со свежими сторами. Сторы создаём здесь, а не в build:
  /// build зовётся заново при каждой смене темы, и экран получил бы новый
  /// пустой стор. UniqueKey — чтобы состояние не переезжало между разделами.
  Widget _sectionScreen(_Section section, {OrderStore? store}) {
    final orders = store ?? _orderStore();
    final screen = switch (section) {
      _Section.myOrders => MyOrdersScreen(
        auth: _auth,
        store: orders,
        onProfile: () => _switchTo(_Section.profile),
      ),
      _Section.nearby => NearbyOrdersScreen(
        store: orders,
        verification: ApiVerificationRepository(ApiClient(_auth)),
        auth: _auth,
        onProfile: () => _switchTo(_Section.profile),
        filters: NearbyFilterStore.persistent()..load(),
      ),
      _Section.profile => ProfileScreen(
        auth: _auth,
        store: orders,
        verification: ApiVerificationRepository(ApiClient(_auth)),
        onMyOrders: () => _switchTo(_Section.myOrders),
        onNearbyOrders: () => _switchTo(_Section.nearby),
        onLogout: _logout,
      ),
    };
    return KeyedSubtree(key: UniqueKey(), child: screen);
  }

  @override
  Widget build(BuildContext context) {
    // пока читаем токен — держим заставку, иначе витрина успеет
    // отрисоваться с гостевым состоянием кнопки
    if (_auth.isRestoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // вопрос о намерении показывается при каждом запуске, выбор нигде не
    // сохраняется. «Ищу автомобиль» ведёт в мои заказы, «Беру заказы» — в
    // «Заказы рядом», «Просто посмотрю» — на витрину
    return _root ??
        IntentScreen(
          onChoose: (intent) => switch (intent) {
            AppIntent.buy => _openMyOrders(),
            AppIntent.work => _openNearbyOrders(),
            AppIntent.browse => _openFeed(),
          },
        );
  }
}

/// Разделы, между которыми переключает [_RootGateState._switchTo].
enum _Section { myOrders, nearby, profile }
