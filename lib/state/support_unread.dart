import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/auth_service.dart';
import '../data/chat_repository.dart';

/// Число непрочитанных в чате поддержки — для бейджей у входов в чат.
/// Пушей нет, поэтому опрашиваем сервер, пока приложение на экране.
/// Число только с сервера (`unread_count`), локально не пересчитываем.
class SupportUnread extends ChangeNotifier with WidgetsBindingObserver {
  SupportUnread(
    this._auth,
    this._repository, {
    this.pollInterval = const Duration(seconds: 60),
  });

  final AuthService _auth;
  final ChatRepository _repository;
  final Duration pollInterval;

  int _count = 0;
  int get count => _count;

  Timer? _timer;
  Future<void>? _refreshing;
  bool _resumed = true;
  bool _chatOpen = false;
  bool? _wasAuthenticated;
  bool _disposed = false;

  /// Подписаться на вход/выход и жизненный цикл приложения.
  void start() {
    WidgetsBinding.instance.addObserver(this);
    _auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  /// Пока открыт экран чата, не опрашиваем: он сам отмечает прочитанное.
  /// Закрыли — сразу спрашиваем сервер, бейдж гаснет без ожидания опроса.
  set chatOpen(bool value) {
    _chatOpen = value;
    if (!value) refresh();
    _schedule();
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

  Future<void> _load() async {
    try {
      final count = await _repository.fetchSupportUnread();
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
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed) refresh();
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (_disposed || !_resumed || _chatOpen || !_auth.isAuthenticated) return;
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
