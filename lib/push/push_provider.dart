/// Через что телефон получает пуши — строка `provider` в POST /me/devices.
/// Ручное зеркало `App\Push\PushProvider` на бекенде.
enum PushProvider {
  /// Firebase Cloud Messaging — телефоны с сервисами Google и iOS.
  fcm('fcm'),

  /// RuStore — Android с установленным RuStore (в том числе без Google).
  rustore('rustore');

  const PushProvider(this.apiValue);

  final String apiValue;
}
