import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/api_config.dart';
import '../firebase_options_dev.dart' as dev;
import '../firebase_options_prod.dart' as prod;
import 'push_messaging.dart';

/// Каналы Android: бекенд указывает их в android.notification.channel_id.
const _channels = [
  AndroidNotificationChannel(
    'orders',
    'Заказы',
    description: 'Отклики, выбор исполнителя, оплата, споры',
    importance: Importance.high,
  ),
  AndroidNotificationChannel(
    'chat',
    'Поддержка',
    description: 'Ответы поддержки',
    importance: Importance.high,
  ),
];

/// [PushMessaging] на firebase_messaging и flutter_local_notifications.
class FirebasePushMessaging implements PushMessaging {
  final _local = FlutterLocalNotificationsPlugin();
  final _localTaps = StreamController<PushMessage>.broadcast();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  @override
  Future<void> init() async {
    // у dev и prod свои приложения в проекте Firebase
    await Firebase.initializeApp(
      options: ApiConfig.isDev
          ? dev.DefaultFirebaseOptions.currentPlatform
          : prod.DefaultFirebaseOptions.currentPlatform,
    );
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final message = _decode(response.payload);
        if (message != null) _localTaps.add(message);
      },
    );
    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    for (final channel in _channels) {
      await android?.createNotificationChannel(channel);
    }
  }

  @override
  Future<bool> requestPermission() async {
    final settings = await _fcm.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  // Классический токен регистрации, а не новый FID из register(): бекенд
  // шлёт через HTTP v1 по message.token, а отправка по FID — другой
  // механизм. Переедем вместе с бекендом, когда его стабилизируют.
  @override
  // ignore: deprecated_member_use
  Future<String?> getToken() => _fcm.getToken();

  @override
  // ignore: deprecated_member_use
  Stream<String> get onTokenRefresh => _fcm.onTokenRefresh;

  @override
  Stream<PushMessage> get onForeground => FirebaseMessaging.onMessage.map(_fromRemote);

  @override
  Stream<PushMessage> get onTap => StreamGroup.merge([
        FirebaseMessaging.onMessageOpenedApp.map(_fromRemote),
        _localTaps.stream,
      ]);

  @override
  Future<PushMessage?> initialTap() async {
    final remote = await _fcm.getInitialMessage();
    if (remote != null) return _fromRemote(remote);
    // запуск тапом по уведомлению, показанному локально
    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      return _decode(launch!.notificationResponse?.payload);
    }
    return null;
  }

  @override
  Future<void> show(PushMessage message) {
    final channel = message.data['type'] == 'chat_message' ? _channels[1] : _channels[0];
    return _local.show(
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

  static PushMessage _fromRemote(RemoteMessage remote) => PushMessage(
        title: remote.notification?.title,
        body: remote.notification?.body,
        data: remote.data,
      );

  static PushMessage? _decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    final data = jsonDecode(payload);
    return data is Map<String, dynamic> ? PushMessage(data: data) : null;
  }
}
