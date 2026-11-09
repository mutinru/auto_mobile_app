import 'dart:async';

import 'package:async/async.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../config/api_config.dart';
import '../firebase_options_dev.dart' as dev;
import '../firebase_options_prod.dart' as prod;
import 'local_notifications.dart';
import 'push_messaging.dart';
import 'push_provider.dart';

/// [PushMessaging] на firebase_messaging; в открытом приложении пуш
/// показывается локально ([LocalNotifications]) — FCM его не покажет.
class FirebasePushMessaging implements PushMessaging {
  final _local = LocalNotifications();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  @override
  PushProvider get provider => PushProvider.fcm;

  @override
  Future<void> init() async {
    // у dev и prod свои приложения в проекте Firebase
    await Firebase.initializeApp(
      options: ApiConfig.isDev
          ? dev.DefaultFirebaseOptions.currentPlatform
          : prod.DefaultFirebaseOptions.currentPlatform,
    );
    await _local.init();
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
  Stream<PushMessage> get onForeground =>
      FirebaseMessaging.onMessage.map(_fromRemote);

  @override
  Stream<PushMessage> get onTap => StreamGroup.merge([
    FirebaseMessaging.onMessageOpenedApp.map(_fromRemote),
    _local.taps,
  ]);

  @override
  Future<PushMessage?> initialTap() async {
    final remote = await _fcm.getInitialMessage();
    if (remote != null) return _fromRemote(remote);
    // запуск тапом по уведомлению, показанному локально
    return _local.launchTap();
  }

  @override
  Future<void> show(PushMessage message) => _local.show(message);

  static PushMessage _fromRemote(RemoteMessage remote) => PushMessage(
    title: remote.notification?.title,
    body: remote.notification?.body,
    data: remote.data,
  );
}
