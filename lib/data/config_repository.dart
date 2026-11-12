import '../models/client_config.dart';

/// Цены и лимиты, которые сервер отдаёт клиенту: комиссия размещения, цена
/// отчёта по VIN, срок осмотра, минимальная сборка. Не хардкодить.
abstract class ConfigRepository {
  /// Цены и лимиты с сервера (GET /config).
  Future<ClientConfig> fetchClientConfig();
}
