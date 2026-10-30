/// Пуш, как его видит приложение: заголовок, текст и data из FCM.
class PushMessage {
  const PushMessage({this.title, this.body, this.data = const {}});

  final String? title;
  final String? body;
  final Map<String, dynamic> data;
}

/// Тонкая прослойка над Firebase и локальными уведомлениями: [PushService]
/// ходит только через неё, поэтому тестируется на фейке без Firebase.
/// Реализация — [FirebasePushMessaging].
abstract class PushMessaging {
  /// Поднять Firebase и каналы уведомлений. Бросает, если пуши здесь
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

  /// Показать пуш локально (приложение открыто).
  Future<void> show(PushMessage message);
}
