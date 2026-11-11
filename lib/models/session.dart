/// Сессия пользователя для «Активных устройств» (GET /me/sessions).
/// [deviceName] присылает приложение при входе (у старых сессий его нет),
/// [platform] — с пуш-устройства этой сессии.
class Session {
  const Session({
    required this.id,
    this.deviceName,
    this.platform,
    this.current = false,
    this.lastUsedAt,
    this.expiresAt,
  });

  final int id;
  final String? deviceName;

  /// `android` | `ios`; null — пуш-устройства у сессии нет.
  final String? platform;

  /// Сессия, с которой открыт экран.
  final bool current;
  final DateTime? lastUsedAt;

  /// Когда истечёт без запросов (скользящий срок на сервере).
  final DateTime? expiresAt;

  /// Как подписать: имя телефона, иначе платформа.
  String get title =>
      deviceName ??
      switch (platform) {
        'android' => 'Устройство Android',
        'ios' => 'Устройство iOS',
        _ => 'Устройство',
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    id: json['id'] as int,
    deviceName: json['device_name'] as String?,
    platform: json['platform'] as String?,
    current: json['current'] as bool? ?? false,
    lastUsedAt: _date(json['last_used_at']),
    expiresAt: _date(json['expires_at']),
  );

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.parse(value).toLocal() : null;
}
