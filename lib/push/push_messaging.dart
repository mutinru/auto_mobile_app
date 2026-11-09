import 'push_provider.dart';

/// Пуш, как его видит приложение: заголовок, текст и data из FCM или RuStore.
class PushMessage {
  const PushMessage({this.title, this.body, this.data = const {}});

  final String? title;
  final String? body;
  final Map<String, dynamic> data;
}

/// Тонкая прослойка над сервисом пушей и локальными уведомлениями:
/// [PushService] ходит только через неё, поэтому тестируется на фейке.
/// Реализации — [FirebasePushMessaging] и [RuStorePushMessaging]; какую
/// взять на этом телефоне, решает [AutoPushMessaging].
abstract class PushMessaging {
  /// Сервис, чей токен отдаёт [getToken], — уходит на сервер вместе с ним.
  PushProvider get provider;

  /// Поднять сервис и каналы уведомлений. Бросает, если пуши здесь
  /// недоступны (нет Play Services, iOS без настройки).
  Future<void> init();

  /// Системный запрос разрешения (Android 13+). true — разрешено.
  Future<bool> requestPermission();

  Future<String?> getToken();

  Stream<String> get onTokenRefresh;

  /// Пуш пришёл, пока приложение открыто: система его не покажет.
  Stream<PushMessage> get onForeground;

  /// Тап по пушу или по локальному уведомлению.
  Stream<PushMessage> get onTap;

  /// Пуш, тапом по которому приложение запустили.
  Future<PushMessage?> initialTap();

  /// Показать пуш локально (приложение открыто). RuStore показывает сам —
  /// у него это пустая операция.
  Future<void> show(PushMessage message);
}
