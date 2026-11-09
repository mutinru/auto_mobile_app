import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rustore_push/flutter_rustore_push.dart';
import 'package:flutter_rustore_push/pigeons/rustore_push.dart' as rustore;

import 'local_notifications.dart';
import 'push_messaging.dart';
import 'push_provider.dart';

/// [PushMessaging] на flutter_rustore_push — для телефонов с RuStore.
///
/// SDK RuStore показывает пуш с `notification` сам, в том числе в открытом
/// приложении, и всё равно зовёт onMessageReceived — поэтому [show] пустой:
/// иначе уведомление задвоится. Каналы (`orders`, `new_orders`, `chat`)
/// SDK не создаёт — их заводит [LocalNotifications].
///
/// SDK инициализирует нативная часть (BitNeBitApplication), если у сборки
/// есть ID проекта RuStore ([isConfigured]); без него этот класс не берут.
class RuStorePushMessaging implements PushMessaging {
  static const _channel = MethodChannel('bitnebit/push');

  /// Есть ли у этой сборки проект RuStore (BuildConfig варианта сборки).
  static Future<bool> isConfigured() async =>
      await _channel.invokeMethod<bool>('rustoreConfigured') ?? false;

  /// RuStore установлен, вход выполнен и пуши ему доступны.
  static Future<bool> isAvailable() => RustorePushClient.available();

  final _local = LocalNotifications();
  final _tokens = StreamController<String>.broadcast();
  final _received = StreamController<PushMessage>.broadcast();
  final _opened = StreamController<PushMessage>.broadcast();

  @override
  PushProvider get provider => PushProvider.rustore;

  @override
  Future<void> init() async {
    await _local.init();
    await RustorePushClient.attachCallbacks(
      onNewToken: (String token) => _tokens.add(token),
      onMessageReceived: (rustore.Message message) =>
          _received.add(_from(message)),
      onMessageOpenedApp: (rustore.Message? message) {
        if (message != null) _opened.add(_from(message));
      },
      onDeletedMessages: () {},
      onError: (String error) => debugPrint('RuStore Push: $error'),
    );
  }

  @override
  Future<bool> requestPermission() => _local.requestPermission();

  @override
  Future<String?> getToken() => RustorePushClient.getToken();

  @override
  Stream<String> get onTokenRefresh => _tokens.stream;

  @override
  Stream<PushMessage> get onForeground => _received.stream;

  @override
  Stream<PushMessage> get onTap => _opened.stream;

  @override
  Future<PushMessage?> initialTap() async {
    final message = await RustorePushClient.getInitialMessage();
    return message == null ? null : _from(message);
  }

  /// SDK уже показал уведомление сам.
  @override
  Future<void> show(PushMessage message) async {}

  static PushMessage _from(rustore.Message message) => PushMessage(
    title: message.notification?.title,
    body: message.notification?.body,
    data: {
      for (final MapEntry(:key, :value) in message.data.entries)
        if (key != null && value != null) key: value,
    },
  );
}
