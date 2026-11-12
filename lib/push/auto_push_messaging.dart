import 'package:flutter/foundation.dart';

import 'firebase_push_messaging.dart';
import 'push_messaging.dart';
import 'push_provider.dart';
import 'rustore_push_messaging.dart';

/// Выбирает сервис пушей для этого телефона при [init]: RuStore, если у
/// сборки есть его проект, а RuStore установлен и доступен, иначе Firebase.
/// Сервер шлёт каждому устройству через его сервис (`provider`), поэтому
/// телефон получает пуш один раз. Выбор — на каждый запуск: поставили или
/// удалили RuStore — новый токен заменит прежний на сервере.
class AutoPushMessaging implements PushMessaging {
  AutoPushMessaging({
    Future<bool> Function()? rustoreReady,
    PushMessaging Function()? rustore,
    PushMessaging Function()? firebase,
  }) : _rustoreReady = rustoreReady ?? _defaultRustoreReady,
       _rustore = rustore ?? RuStorePushMessaging.new,
       _firebase = firebase ?? FirebasePushMessaging.new;

  final Future<bool> Function() _rustoreReady;
  final PushMessaging Function() _rustore;
  final PushMessaging Function() _firebase;

  late PushMessaging _impl;

  static Future<bool> _defaultRustoreReady() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    return await RuStorePushMessaging.isConfigured() &&
        // RuStore отвечает быстро; завис — не держим пуши, берём Firebase
        await RuStorePushMessaging.isAvailable().timeout(
          const Duration(seconds: 5),
        );
  }

  @override
  Future<void> init() async {
    var ready = false;
    try {
      ready = await _rustoreReady();
    } catch (e) {
      debugPrint('RuStore недоступен: $e');
    }
    if (ready) {
      try {
        _impl = _rustore();
        await _impl.init();
        return;
      } catch (e) {
        debugPrint('RuStore не поднялся, берём Firebase: $e');
      }
    }
    _impl = _firebase();
    await _impl.init();
  }

  @override
  PushProvider get provider => _impl.provider;

  @override
  Future<bool> requestPermission() => _impl.requestPermission();

  @override
  Future<String?> getToken() => _impl.getToken();

  @override
  Future<void> deleteToken() => _impl.deleteToken();

  @override
  Stream<String> get onTokenRefresh => _impl.onTokenRefresh;

  @override
  Stream<PushMessage> get onForeground => _impl.onForeground;

  @override
  Stream<PushMessage> get onTap => _impl.onTap;

  @override
  Future<PushMessage?> initialTap() => _impl.initialTap();

  @override
  Future<void> show(PushMessage message) => _impl.show(message);
}
