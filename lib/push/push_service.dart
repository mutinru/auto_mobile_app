import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/auth_service.dart';
import '../data/device_repository.dart';
import '../models/push_target.dart';
import '../state/notification_unread.dart';
import '../state/support_unread.dart';
import 'push_messaging.dart';

/// Пуши: один на приложение, создаётся в main(). Регистрирует FCM-токен
/// после входа, в открытом приложении обновляет бейджи и показывает пуш
/// локально, тап превращает в [PushTarget] для корня ([taps]). Экраны сам
/// не открывает: навигация — дело _RootGate.
///
/// Сбой Firebase не роняет приложение — пуши просто выключены, остаётся
/// опрос бейджей.
class PushService {
  PushService({
    required this._auth,
    required this._devices,
    required this._messaging,
    this.notifications,
    this.support,
    this.platform = 'android',
  });

  final AuthService _auth;
  final DeviceRepository _devices;
  final PushMessaging _messaging;
  final NotificationUnread? notifications;
  final SupportUnread? support;
  final String platform;

  final _taps = StreamController<PushTarget>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];

  bool _enabled = false;
  bool get enabled => _enabled;

  /// Сессия (токен API), для которой устройство уже зарегистрировано.
  String? _registeredFor;

  /// Разрешение спрашиваем один раз за запуск: отказ системный диалог
  /// запоминает сам.
  bool _askedPermission = false;

  PushTarget? _pendingTap;

  /// Тапы по пушам — корень открывает по ним экраны.
  Stream<PushTarget> get taps => _taps.stream;

  /// Тап, которым приложение запустили: он приходит до того, как корень
  /// подписался на [taps], поэтому корень забирает его сам — один раз.
  PushTarget? takePendingTap() {
    final tap = _pendingTap;
    _pendingTap = null;
    return tap;
  }

  Future<void> start() async {
    try {
      await _messaging.init();
    } catch (e) {
      debugPrint('Пуши выключены: $e');
      return;
    }
    _enabled = true;

    _subscriptions
      ..add(_messaging.onForeground.listen(_onForeground))
      ..add(_messaging.onTap.listen(_onTap))
      ..add(_messaging.onTokenRefresh.listen((token) {
        if (_auth.isAuthenticated) _register(token);
      }));
    _auth.addListener(_onAuthChanged);

    try {
      final initial = await _messaging.initialTap();
      _pendingTap = initial == null ? null : PushTarget.fromData(initial.data);
    } catch (e) {
      debugPrint('Пуш запуска не прочитан: $e');
    }
    _onAuthChanged();
  }

  void dispose() {
    _auth.removeListener(_onAuthChanged);
    for (final s in _subscriptions) {
      s.cancel();
    }
    _taps.close();
  }

  /// Новая сессия — регистрируем устройство. Выход сервер отрабатывает
  /// сам: устройство удаляется вместе с токеном сессии.
  void _onAuthChanged() {
    final session = _auth.token;
    if (session == null) {
      _registeredFor = null;
      return;
    }
    if (session == _registeredFor) return;
    _registeredFor = session;
    _registerCurrent();
  }

  Future<void> _registerCurrent() async {
    try {
      if (!_askedPermission) {
        _askedPermission = true;
        await _messaging.requestPermission();
      }
      final token = await _messaging.getToken();
      if (token != null) await _register(token);
    } catch (e) {
      debugPrint('FCM-токен не получен: $e');
    }
  }

  Future<void> _register(String token) async {
    try {
      await _devices.register(token, platform);
    } catch (e) {
      // следующий вход или обновление токена попробуют снова
      _registeredFor = null;
      debugPrint('Устройство не зарегистрировано: $e');
    }
  }

  /// Приложение открыто: система пуш не покажет. Бейджи — сразу с сервера;
  /// ответ поддержки при открытом чате не показываем — он и так на экране.
  Future<void> _onForeground(PushMessage message) async {
    final target = PushTarget.fromData(message.data);
    if (target is SupportChatTarget) {
      support?.refresh();
      if (support?.chatOpen ?? false) return;
    } else {
      notifications?.refresh();
    }
    try {
      await _messaging.show(message);
    } catch (e) {
      debugPrint('Пуш не показан: $e');
    }
  }

  void _onTap(PushMessage message) {
    final target = PushTarget.fromData(message.data);
    if (target != null) _taps.add(target);
  }
}
