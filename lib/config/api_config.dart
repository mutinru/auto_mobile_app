import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  ApiConfig._();

  /// Хост, на котором поднят бекенд (docker compose, nginx на 8083).
  ///
  /// Внутри Android-эмулятора localhost — это сам эмулятор, а машина
  /// разработчика доступна по служебному адресу 10.0.2.2.
  ///
  /// Для запуска на реальном телефоне подставь сюда LAN-адрес машины
  /// с бекендом (например, http://192.168.1.5:8083/api) — телефон
  /// должен быть в той же сети.
  /// Хост без /api — фото приходят относительными путями (/storage/...).
  static String get origin => baseUrl.replaceFirst(RegExp(r'/api$'), '');

  static String get baseUrl {
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8083/api';
    }
    return 'http://localhost:8083/api';
  }
}
