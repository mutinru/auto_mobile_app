import '../push/push_provider.dart';

/// Устройства для пушей (POST /me/devices). Удалять при выходе не нужно:
/// сервер стирает устройство вместе с токеном сессии, а новый токен той же
/// сессии (сменился сервис) заменяет прежний.
abstract class DeviceRepository {
  /// [platform] — `android` или `ios`; [provider] — чей это токен.
  Future<void> register(String token, String platform, PushProvider provider);
}
