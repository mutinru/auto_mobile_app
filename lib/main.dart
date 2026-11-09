import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/api_chat_repository.dart';
import 'data/address_repository.dart';
import 'data/api_client.dart';
import 'data/api_device_repository.dart';
import 'data/api_notification_repository.dart';
import 'data/api_order_repository.dart';
import 'data/api_verification_repository.dart';
import 'data/auth_service.dart';
import 'data/car_catalog_repository.dart';
import 'data/city_repository.dart';
import 'data/location_service.dart';
import 'l10n/app_locale.dart';
import 'models/order.dart';
import 'models/order_kind.dart';
import 'models/push_target.dart';
import 'navigation/section_nav.dart';
import 'push/auto_push_messaging.dart';
import 'push/push_service.dart';
import 'screens/intent_screen.dart';
import 'screens/my_orders_screen.dart';
import 'screens/nearby_orders_screen.dart';
import 'screens/new_inspection_screen.dart';
import 'screens/new_order_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/auto_refresh.dart';
import 'screens/order_routes.dart';
import 'screens/phone_login_screen.dart';
import 'screens/public_feed_screen.dart';
import 'screens/profile_screen.dart';
import 'state/city_locator.dart';
import 'state/last_section.dart';
import 'state/nearby_filter_store.dart';
import 'state/notification_scope.dart';
import 'state/notification_unread.dart';
import 'state/order_store.dart';
import 'state/support_chat_scope.dart';
import 'state/support_unread.dart';
import 'state/verification_status.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/order_kind_sheet.dart';
import 'widgets/support_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // тему читаем до первого кадра, иначе светлая мигнёт тёмной
  final theme = ThemeController();
  await theme.load();
  // последний раздел — тоже до первого кадра: вошедший попадает в него
  // сразу, вопрос о намерении не мелькает
  final lastSection = LastSection.secure();
  await lastSection.load();
  final auth = AuthService();
  // бейджи непрочитанных поддержки: одна сессия — один счётчик
  final unread = SupportUnread(auth, ApiChatRepository(ApiClient(auth)))
    ..start();
  // бейдж колокольчика в шапках разделов — тоже один на сессию
  final notifications = NotificationUnread(
    auth,
    ApiNotificationRepository(ApiClient(auth)),
  )..start();
  // пуши: сервис (RuStore или Firebase) выбирается и поднимается в фоне,
  // первый кадр его не ждёт
  final push = PushService(
    auth: auth,
    devices: ApiDeviceRepository(ApiClient(auth)),
    messaging: AutoPushMessaging(),
    notifications: notifications,
    support: unread,
  );
  unawaited(push.start());
  runApp(
    AutoPodborApp(
      theme: theme,
      auth: auth,
      unread: unread,
      notifications: notifications,
      push: push,
      lastSection: lastSection,
    ),
  );
}

class AutoPodborApp extends StatelessWidget {
  const AutoPodborApp({
    super.key,
    required this.theme,
    required this.auth,
    this.unread,
    this.notifications,
    this.push,
    this.lastSection,
  });

  final ThemeController theme;

  /// Одна сессия на приложение. Создаётся здесь, а не в _RootGate: чат
  /// поддержки открывается из шторки на любом маршруте, и SupportChatScope
  /// должен стоять выше Navigator.
  final AuthService auth;

  /// Непрочитанные в чате поддержки — для бейджей у входов в чат.
  final SupportUnread? unread;

  /// Непрочитанные уведомления — для колокольчиков в шапках разделов.
  final NotificationUnread? notifications;

  /// Пуши — тапы по ним открывает _RootGate.
  final PushService? push;

  /// Последний выбранный раздел. null — без автоперехода при запуске.
  final LastSection? lastSection;

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
          // язык закреплён — см. app_locale.dart
          locale: appLocale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          // экраны заказа перечитывают заказ, когда на них возвращаются
          navigatorObservers: [appRouteObserver],
          // у экранов нет AppBar, поэтому иконки статус-бара красим здесь:
          // тёмные на светлой теме, светлые на тёмной
          builder: (context, child) => SupportChatScope(
            auth: auth,
            unread: unread,
            child: NotificationScope(
              auth: auth,
              unread: notifications,
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: theme.isLight
                    ? SystemUiOverlayStyle.dark
                    : SystemUiOverlayStyle.light,
                child: child!,
              ),
            ),
          ),
          home: _RootGate(auth: auth, push: push, lastSection: lastSection),
        ),
      ),
    );
  }
}

/// Стартовый экран для всех — вопрос о намерении ([IntentScreen], кадр 01
/// макета car-storefront-modes.html), за ним экран выбранного режима:
/// «Ищу автомобиль» → [MyOrdersScreen], «Беру заказы» → [NearbyOrdersScreen],
/// «Просто посмотрю» → [PublicFeedScreen]. Первые два требуют токен, поэтому
/// гостя ведут через вход. Вопрос всегда лежит в корне, выбранный раздел —
/// «дом» — поверх него, профиль и разделы из профиля — ещё выше; правила
/// стека — в [SectionNav]. «Назад» из дома ведёт к вопросу, с вопроса —
/// выход. Вошедшему при запуске дом открывается сразу ([LastSection]).
/// Держит [AuthService] и отдаёт [OrderStore] на реальном API в разделы.
///
/// Экраны одиночного осмотра (InspectionOverviewScreen) остаются
/// самостоятельным модулем — из этого хаба пока не достижимы напрямую,
/// подключаются к заказу отдельным проходом (см. "Старт осмотра" в макете).
class _RootGate extends StatefulWidget {
  const _RootGate({required this.auth, this.push, this.lastSection});

  final AuthService auth;
  final PushService? push;
  final LastSection? lastSection;

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  late final _auth = widget.auth;

  /// Один на приложение: справочник кешируется на всю сессию, а сторы
  /// заказов создаются заново на каждый раздел.
  late final _carCatalog = ApiCarCatalogRepository(ApiClient(_auth));
  late final _cities = ApiCityRepository(ApiClient(_auth));
  late final _cityLocator = CityLocator(
    _cities,
    const GeolocatorLocationService(),
  );
  late final _addresses = ApiAddressRepository(ApiClient(_auth));

  /// Верификация — одна на сессию входа: экраны разделов пересоздаются, а
  /// статус должен рисоваться сразу, без мигания гейта.
  late final _verification = VerificationStatus(
    ApiVerificationRepository(ApiClient(_auth)),
  );

  @override
  void initState() {
    super.initState();
    // пробуем поднять прошлую сессию с диска
    _auth.restore().then((_) {
      if (!mounted) return;
      setState(() {});
      _warmUpCity();
      // тапом по пушу приложение запустили — сессия уже поднята; экран
      // пуша — поверх дома, чтобы «назад» вёл туда, а не к вопросу
      final tap = widget.push?.takePendingTap();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openLastSection();
        if (tap != null) _openPush(tap);
      });
    });
    _auth.addListener(_onAuthChanged);
    _auth.addListener(_warmUpCity);
    _pushTaps = widget.push?.taps.listen(_openPush);
  }

  StreamSubscription<PushTarget>? _pushTaps;

  /// Прогрев уже запущен в этой сессии входа — [AuthService] уведомляет
  /// часто (профиль, выход), второй раз GPS не дёргаем.
  bool _cityWarmedUp = false;

  /// Город по GPS фоном сразу после входа: формы и фильтры получат его
  /// без ожидания. /cities/nearest требует токен, поэтому только вошедшему.
  /// Разрешение тут не спрашивается — см. [CityLocator.warmUp].
  void _warmUpCity() {
    if (!_auth.isAuthenticated || _auth.isRestoring) {
      _cityWarmedUp = false;
      // вышел или сессия истекла — статус верификации был чужим
      if (!_auth.isRestoring) _verification.clear();
      return;
    }
    if (_cityWarmedUp) return;
    _cityWarmedUp = true;
    unawaited(_cityLocator.warmUp());
  }

  @override
  void dispose() {
    _pushTaps?.cancel();
    _auth.removeListener(_onAuthChanged);
    _auth.removeListener(_warmUpCity);
    super.dispose();
  }

  /// Тап по пушу: экран открывается поверх текущего раздела, «назад»
  /// возвращает туда, где был пользователь. Гостю (вышел, а пуш остался в
  /// шторке) — ничего: заказ без токена не открыть.
  Future<void> _openPush(PushTarget target) async {
    if (!mounted || !_auth.isAuthenticated || _auth.isRestoring) return;
    switch (target) {
      case SupportChatTarget():
        final scope = SupportChatScope.maybeOf(context);
        if (scope != null) await pushSupportChat(Navigator.of(context), scope);
      case NearbyOrdersTarget():
        _openNearbyOrders();
      case OrderTarget():
        final feed = NotificationScope.maybeOf(context);
        final id = target.notificationId;
        if (feed != null && id != null) {
          // прочитано — как тап в ленте; не вышло — не повод не открывать
          unawaited(
            feed
                .repository()
                .markRead(id)
                .then((_) => feed.unread?.refresh(), onError: (_) {}),
          );
        }
        if (target.opensOrder) {
          await openOrderScreen(
            context,
            store: _orderStore(),
            auth: _auth,
            orderId: target.orderId,
            isInspection: target.orderKind.isInspection,
            asExecutor: !target.viewerIsCustomer,
          );
        } else {
          await openNotifications(context, store: _orderStore(), auth: _auth);
        }
    }
  }

  /// Сервер ответил 401 — токен отозван или протух. Снимаем раздел и всё,
  /// что над ним, и ведём на вход; после входа возвращаем в тот же раздел.
  /// Без этого каждый экран показывал бы «Сессия истекла», а выйти из
  /// тупика можно было только переустановкой.
  void _onAuthChanged() {
    if (!_auth.sessionExpired || !mounted) return;
    _auth.consumeSessionExpired();
    final section = _nav.home;
    final messenger = ScaffoldMessenger.of(context);
    _nav.reset();
    messenger.showSnackBar(
      const SnackBar(content: Text('Сессия истекла — войдите заново')),
    );
    // гостю (витрина, вопрос о намерении) вход не навязываем
    if (section == null) return;
    _pushLogin(
      onLoggedIn: () => _openHome(section),
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
  void _openMyOrders() => _openSection(HomeSection.myOrders);

  /// «Беру заказы на подбор» ведёт в «Заказы рядом». /orders/available
  /// требует токен, поэтому гостя, как и в «Ищу автомобиль», сначала
  /// проводим через вход.
  void _openNearbyOrders() => _openSection(HomeSection.nearby);

  void _openSection(HomeSection section) {
    if (_auth.isAuthenticated) {
      _chooseHome(section);
    } else {
      // вход открыт с вопроса о намерении, а не с витрины: «без входа»
      // подменяем витриной, чтобы «назад» с неё вёл к вопросу
      _pushLogin(
        onLoggedIn: () => _chooseHome(section),
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
          ? NewInspectionScreen(store: store, auth: _auth)
          : NewOrderScreen(store: store),
    );
    final created = replace
        ? await navigator.pushReplacement<Order, void>(route)
        : await navigator.push(route);
    if (created != null && mounted) {
      _openHome(HomeSection.myOrders, store: store);
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

  OrderStore _orderStore() => OrderStore(
    ApiOrderRepository(ApiClient(_auth)),
    catalog: _carCatalog,
    cities: _cities,
    locator: _cityLocator,
    addresses: _addresses,
  );

  /// Стек разделов: вопрос → дом → профиль → другой раздел, без копий.
  late final _nav = SectionNav(() => Navigator.of(context));

  /// Выбор на вопросе о намерении: раздел становится домом и запоминается —
  /// при следующем запуске откроется сразу.
  void _chooseHome(HomeSection section) {
    unawaited(widget.lastSection?.save(section));
    _openHome(section);
  }

  /// Дом поверх вопроса — со свежим стором или стором только что
  /// созданного заказа, чтобы тот был виден сразу.
  void _openHome(
    HomeSection section, {
    OrderStore? store,
    bool animate = true,
  }) => _nav.openHome(
    section,
    () => _sectionScreen(section, store ?? _orderStore()),
    animate: animate,
  );

  /// Запуск вошедшего: сразу в последний дом, без анимации появления.
  void _openLastSection() {
    final section = widget.lastSection?.value;
    if (section == null || !_auth.isAuthenticated || _nav.home != null) {
      return;
    }
    _openHome(section, animate: false);
  }

  /// Иконка профиля в любом разделе. Разделы, открытые из профиля, делят
  /// его стор: счётчики профиля видят те же списки, что и экран поверх.
  void _openProfile() => _nav.openProfile(() {
    final store = _orderStore();
    return ProfileScreen(
      auth: _auth,
      store: store,
      verification: _verification,
      onMyOrders: () => _nav.openFromProfile(
        HomeSection.myOrders,
        () => _sectionScreen(HomeSection.myOrders, store),
      ),
      onNearbyOrders: () => _nav.openFromProfile(
        HomeSection.nearby,
        () => _sectionScreen(HomeSection.nearby, store),
      ),
      onLogout: _logout,
    );
  });

  /// Выход: снова виден вопрос о намерении, последний раздел забыт. Сторы
  /// создаются заново на каждый раздел, поэтому данные прошлого
  /// пользователя выход не переживут.
  Future<void> _logout() async {
    await _auth.logout();
    await widget.lastSection?.clear();
    if (!mounted) return;
    _nav.reset();
  }

  /// Экран раздела. Зовётся из фабрики [SectionNav] один раз на маршрут —
  /// не в `builder`, иначе смена темы пересоздала бы сторы.
  Widget _sectionScreen(HomeSection section, OrderStore orders) =>
      switch (section) {
        HomeSection.myOrders => MyOrdersScreen(
          auth: _auth,
          store: orders,
          onProfile: _openProfile,
        ),
        HomeSection.nearby => NearbyOrdersScreen(
          store: orders,
          verification: _verification,
          auth: _auth,
          onProfile: _openProfile,
          filters: NearbyFilterStore.persistent(
            // фильтры — свои у каждого аккаунта; после офлайн-старта профиля
            // ещё может не быть
            userId: () async {
              await _auth.ensureUser();
              return _auth.user?.id;
            },
            locator: _cityLocator,
          )..load(),
        ),
      };

  @override
  Widget build(BuildContext context) {
    // пока читаем токен — держим заставку, иначе витрина успеет
    // отрисоваться с гостевым состоянием кнопки
    if (_auth.isRestoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // вопрос о намерении всегда в корне: гость видит его при запуске,
    // вошедший — по «назад» из дома ([LastSection] открывает дом сразу).
    // «Ищу автомобиль» ведёт в мои заказы, «Беру заказы» — в «Заказы рядом»,
    // «Просто посмотрю» — на витрину
    // колокольчик — только вошедшему; вход и выход перерисовывают шапку
    return ListenableBuilder(
      listenable: _auth,
      builder: (context, _) => IntentScreen(
        signedIn: _auth.isAuthenticated,
        onChoose: (intent) => switch (intent) {
          AppIntent.buy => _openMyOrders(),
          AppIntent.work => _openNearbyOrders(),
          AppIntent.browse => _openFeed(),
        },
        onNotifications: _auth.isAuthenticated
            ? () => openNotifications(
                context,
                store: _orderStore(),
                auth: _auth,
              )
            : null,
      ),
    );
  }
}
