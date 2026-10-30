/// Устройства для пушей (POST /me/devices). Удалять при выходе не нужно:
/// сервер стирает устройство вместе с токеном сессии.
abstract class DeviceRepository {
  /// [platform] — `android` или `ios`.
  Future<void> register(String token, String platform);
}
