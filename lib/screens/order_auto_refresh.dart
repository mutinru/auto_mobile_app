import 'dart:async';

import 'package:flutter/widgets.dart';

import '../state/notification_unread.dart';
import '../state/notification_scope.dart';
import '../widgets/api_error.dart';

/// Наблюдатель маршрутов приложения: по нему экран заказа узнаёт, что его
/// снова открыли (закрыли чат поддержки, ленту, шторку). Стоит в
/// `MaterialApp.navigatorObservers`; без него (виджет-тесты) возврат на
/// экран просто не замечается.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();

/// Экран заказа сам перечитывает заказ (QA №33): другая сторона платит,
/// подтверждает, откликается, поддержка решает спор — а экран открыт.
///
/// Перечитываем, когда:
/// - вернулись на экран с другого маршрута ([appRouteObserver]);
/// - приложение вернулось из фона;
/// - вырос счётчик непрочитанных уведомлений — событие другой стороны
///   сервер всегда шлёт уведомлением, а пуш в открытом приложении сразу
///   переспрашивает счётчик ([NotificationUnread]);
/// - раз в [pollInterval] — страховка, если уведомления нет.
///
/// Пока поверх экрана шторка или другой маршрут, либо приложение в фоне, не
/// перечитываем: вернувшись, перечитаем всё равно.
///
/// Экран отдаёт [refreshOrder] — тихое перечитывание без спиннера, ошибки
/// бросает наружу; [refreshPaused] — идёт первая загрузка или действие
/// пользователя, ответ опроса его результат не затрёт.
mixin OrderAutoRefresh<T extends StatefulWidget> on State<T> {
  static const pollInterval = Duration(seconds: 30);

  /// Перечитать заказ с сервера и показать. Ошибку — бросить.
  @protected
  Future<void> refreshOrder();

  /// true — сейчас не перечитываем (идёт загрузка или действие).
  @protected
  bool get refreshPaused;

  late final _observer = _Observer(this);
  ModalRoute<void>? _route;
  NotificationUnread? _unread;
  int _seenUnread = 0;
  Timer? _timer;
  Future<void>? _inFlight;
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_observer);
    _timer = Timer.periodic(pollInterval, (_) => _auto());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      appRouteObserver.unsubscribe(_observer);
      _route = route;
      if (route != null) appRouteObserver.subscribe(_observer, route);
    }
    final unread = NotificationScope.maybeOf(context)?.unread;
    if (unread != _unread) {
      _unread?.removeListener(_onUnread);
      _unread = unread?..addListener(_onUnread);
      _seenUnread = unread?.count ?? 0;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(_observer);
    appRouteObserver.unsubscribe(_observer);
    _unread?.removeListener(_onUnread);
    super.dispose();
  }

  /// Перечитать по жесту «потянуть вниз»: ошибку показываем.
  @protected
  Future<void> pullToRefresh() async {
    try {
      await _reload();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  /// Параллельные вызовы делят один запрос.
  Future<void> _reload() =>
      _inFlight ??= refreshOrder().whenComplete(() => _inFlight = null);

  bool get _visible => _resumed && (_route?.isCurrent ?? true);

  /// Автоматическое перечитывание: молча, ошибка — до следующего повода.
  void _auto() {
    if (!mounted) return;
    if (!_visible || refreshPaused) return;
    _reload().catchError((_) {
      // нет сети — покажем то, что есть; опрос попробует снова
    });
  }

  void _onUnread() {
    final count = _unread?.count ?? 0;
    final grew = count > _seenUnread;
    _seenUnread = count;
    if (grew) _auto();
  }

  void _onPopNext() => _auto();

  void _onLifecycle(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed) _auto();
  }
}

/// Подписки миксина: сам он не может подмешать [RouteAware] и
/// [WidgetsBindingObserver] к чужому `State`.
class _Observer with WidgetsBindingObserver, RouteAware {
  _Observer(this._owner);

  final OrderAutoRefresh _owner;

  @override
  void didPopNext() => _owner._onPopNext();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _owner._onLifecycle(state);
}
