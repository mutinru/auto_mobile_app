import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Конфигурация API: хост и пути.
///
/// Адрес выбирается по flavor сборки:
/// - `dev`  → локальный бекенд (docker compose, nginx на :8083)
/// - `prod` → https://bitnebit.com/api
///
/// Flavor задаётся при сборке: `flutter run --flavor dev` или
/// `flutter build apk --flavor prod`.
class ApiConfig {
  ApiConfig._();

  /// Текущий flavor. Flutter передаёт его автоматически при использовании
  /// `--flavor` (через нативные настройки Android/iOS).
  static const String flavor = String.fromEnvironment(
    'FLUTTER_APP_FLAVOR',
    defaultValue: 'prod',
  );

  static bool get isDev => flavor == 'dev';
  static bool get isProd => flavor == 'prod';

  /// Хост без `/api` — фото приходят относительными путями (/storage/...).
  static String get origin => baseUrl.replaceFirst(RegExp(r'/api$'), '');

  static String get baseUrl {
    if (isProd) {
      return 'https://bitnebit.com/api';
    }

    // dev
    if (!kIsWeb && Platform.isAndroid) {
      // Внутри Android-эмулятора localhost — это сам эмулятор,
      // машина разработчика доступна по служебному адресу 10.0.2.2.
      return 'http://10.0.2.2:8083/api';
    }
    return 'http://localhost:8083/api';
  }
}
