import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Сборка, в которой работает приложение: номер (`versionCode` /
/// `CFBundleVersion`, задаёт `make` через `--build-number`), пакет и
/// магазин, из которого её поставили. Читается один раз в `main` до
/// первого кадра ([load]); без плагина (тесты) или при сбое номер
/// неизвестен, и проверка обновления молчит.
abstract final class AppBuild {
  static AppBuildInfo? _info;

  /// Номер сборки; null — неизвестен.
  static int? get number => _info?.number;

  static AppBuildInfo? get info => _info;

  static Future<void> load() async {
    try {
      final p = await PackageInfo.fromPlatform();
      _info = AppBuildInfo(
        number: int.tryParse(p.buildNumber),
        packageName: p.packageName,
        installerStore: p.installerStore,
      );
    } catch (_) {
      _info = null;
    }
  }

  @visibleForTesting
  static set debugInfo(AppBuildInfo? info) => _info = info;
}

@immutable
class AppBuildInfo {
  const AppBuildInfo({
    required this.number,
    required this.packageName,
    this.installerStore,
  });

  final int? number;
  final String packageName;

  /// Пакет магазина-установщика: `com.android.vending` — Google Play,
  /// `ru.vk.store` — RuStore; null — поставили APK вручную или iOS.
  final String? installerStore;
}
