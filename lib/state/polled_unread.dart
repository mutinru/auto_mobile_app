import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/auth_service.dart';

/// Число непрочитанных для бейджа. Пушей нет, поэтому опрашиваем сервер,
/// пока приложение на экране; гостю — 0 без запроса. Число только с
/// сервера, локально не пересчитываем. Что спрашивать — [fetchCount]
/// наследника ([SupportUnread], [NotificationUnread]).
abstract class PolledUnread extends ChangeNotifier with WidgetsBindingObserver {
  PolledUnread(this._auth, {this.pollInterval = const Duration(seconds: 60)});

  final AuthService _auth;
  final Duration pollInterval;

  int _count = 0;
  int get count => _count;

  Timer? _timer;
  Future<void>? _refreshing;
  bool _resumed = true;
  bool? _wasAuthenticated;
  bool _disposed = false;

  /// Запрос числа на сервер.
  @protected
  Future<int> fetchCount();

  /// true — опрос на паузе (у поддержки — пока открыт чат).
  @protected
  bool get paused => false;

  /// Подписаться на вход/выход и жизненный цикл приложения.
  void start() {
    WidgetsBinding.instance.addObserver(this);
    _auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  /// Гость — 0 без запроса. Ошибку глотаем: останется прежнее число.
  /// Параллельные вызовы делят один запрос.
  Future<void> refresh() {
    if (!_auth.isAuthenticated) {
      _set(0);
      return Future.value();
    }
    return _refreshing ??= _load().whenComplete(() => _refreshing = null);
  }

  /// Число уже пришло с сервера другим запросом (страница ленты, «прочитать
  /// все») — принимаем его без лишнего опроса.
  void report(int count) {
    if (_auth.isAuthenticated) _set(count);
  }

  Future<void> _load() async {
    try {
      final count = await fetchCount();
      // пока ждали ответ, могли выйти
      if (_auth.isAuthenticated) _set(count);
    } catch (_) {
      // нет сети — покажем прежнее число, опрос попробует снова
    }
  }

  /// AuthService шумит и при загрузке профиля — реагируем только на смену
  /// «вошёл / не вошёл».
  void _onAuthChanged() {
    final authenticated = _auth.isAuthenticated;
    if (authenticated == _wasAuthenticated) return;
    _wasAuthenticated = authenticated;
    refresh();
    schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed) refresh();
    schedule();
  }

  /// Перезапустить таймер опроса — после смены [paused].
  @protected
  void schedule() {
    _timer?.cancel();
    _timer = null;
    if (_disposed || !_resumed || paused || !_auth.isAuthenticated) return;
    _timer = Timer.periodic(pollInterval, (_) => refresh());
  }

  void _set(int count) {
    if (count == _count || _disposed) return;
    _count = count;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
