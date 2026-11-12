import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/app_build.dart';
import '../models/client_config.dart';

/// Принудительное обновление (ревью №11). Сервер держит минимальную сборку
/// (`min_build` в `GET /config`) и отвечает 426 на запросы старой сборки
/// (`X-App-Build` ставит [HttpTransport]). Любой из двух сигналов включает
/// [required], и вместо всего приложения встаёт экран «Обновите
/// приложение» (`main.dart`). Обратно не выключается: обновлённое
/// приложение — это новый процесс.
abstract final class AppUpdate {
  static final required = ValueNotifier<bool>(false);

  /// Ответ сервера 426 — сборка устарела.
  static void markRequired() => required.value = true;

  /// Сверить сборку с сервером при запуске. Сбой сети и неизвестный номер
  /// сборки не блокируют: проверка повторится на следующем запросе (426).
  static Future<void> checkOnStart(ApiClient client) async {
    final own = AppBuild.number;
    if (own == null) return;
    try {
      final json = await client.get('/config');
      final config = ClientConfig.fromJson(
        json['data'] as Map<String, dynamic>,
      );
      if (config.minBuild > own) markRequired();
    } catch (_) {
      // нет сети или 426 (его уже отметил транспорт)
    }
  }

  @visibleForTesting
  static void debugReset() => required.value = false;
}
