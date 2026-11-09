import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'push_messaging.dart';

/// Каналы Android: бекенд указывает их в android.notification.channel_id.
/// Создаёт их приложение — и для Firebase, и для RuStore (SDK RuStore сам
/// каналы не заводит).
const pushChannels = [
  AndroidNotificationChannel(
    'orders',
    'Заказы',
    description: 'Отклики, выбор исполнителя, оплата, споры',
    importance: Importance.high,
  ),
  AndroidNotificationChannel(
    'new_orders',
    'Новые заказы рядом',
    description: 'Новые заказы в городах вашей подписки',
    importance: Importance.high,
  ),
  AndroidNotificationChannel(
    'chat',
    'Поддержка',
    description: 'Ответы поддержки',
    importance: Importance.high,
  ),
];

/// Канал по типу пуша — тот же, что назначает бекенд.
AndroidNotificationChannel channelFor(PushMessage message) {
  final id = switch (message.data['type']) {
    'chat_message' => 'chat',
    'new_order' || 'new_orders' => 'new_orders',
    _ => 'orders',
  };
  return pushChannels.firstWhere((c) => c.id == id);
}

/// Каналы и локальный показ пуша на flutter_local_notifications — общее у
/// реализаций [PushMessaging].
class LocalNotifications {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<PushMessage>.broadcast();

  /// Тапы по уведомлениям, показанным через [show].
  Stream<PushMessage> get taps => _taps.stream;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<void> init() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final message = _decode(response.payload);
        if (message != null) _taps.add(message);
      },
    );
    for (final channel in pushChannels) {
      await _android?.createNotificationChannel(channel);
    }
  }

  /// Системный запрос разрешения на уведомления (Android 13+).
  Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? false;

  /// Приложение запущено тапом по уведомлению из [show].
  Future<PushMessage?> launchTap() async {
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      return _decode(launch!.notificationResponse?.payload);
    }
    return null;
  }

  Future<void> show(PushMessage message) {
    final channel = channelFor(message);
    return _plugin.show(
      // id — чтобы новые не затирали друг друга
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000 % 0x7fffffff,
      title: message.title,
      body: message.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static PushMessage? _decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    final data = jsonDecode(payload);
    return data is Map<String, dynamic> ? PushMessage(data: data) : null;
  }
}
