import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Имя телефона для «Активных устройств» («Google Pixel 8», «iPhone 15»)
/// — уходит при входе (device_name). Удобство, а не условие входа: любой
/// сбой (в виджет-тестах плагина нет) — null, сервер покажет платформу.
Future<String?> deviceName() async {
  try {
    final info = DeviceInfoPlugin();
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _android(await info.androidInfo),
      TargetPlatform.iOS => (await info.iosInfo).modelName,
      _ => null,
    };
  } catch (_) {
    return null;
  }
}

/// «Google Pixel 8»: производитель, если модель его не начинает.
String _android(AndroidDeviceInfo a) {
  final maker = a.manufacturer.trim();
  final model = a.model.trim();
  if (maker.isEmpty || model.toLowerCase().startsWith(maker.toLowerCase())) {
    return model;
  }
  return '${maker[0].toUpperCase()}${maker.substring(1)} $model';
}
