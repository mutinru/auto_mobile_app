/// Контакты поддержки.
///
/// Телефона нет намеренно: поддержка — чат и Telegram (QA №25). Ник
/// Telegram — из макета design/first-launch-screen.html, до запуска сверить.
/// Чат в приложении — только для вошедших (SupportChatScreen),
/// гостя пункт «Написать в чат» ведёт в этот же Telegram.
class SupportConfig {
  SupportConfig._();

  /// Ник без @ — для https://t.me/<ник>.
  static const telegram = 'bitnebit_support';

  static Uri get telegramUri => Uri.https('t.me', '/$telegram');
}
