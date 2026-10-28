/// Контакты поддержки.
///
/// ЗАГЛУШКИ из макета design/first-launch-screen.html — до запуска заменить
/// на настоящие. Чата в приложении нет (на бекенде под него ничего нет),
/// пункт «Написать в чат» ведёт в тот же Telegram.
class SupportConfig {
  SupportConfig._();

  /// Как показываем номер.
  static const phoneDisplay = '8 800 000-00-00';

  /// Как набираем — для tel:.
  static const phoneDial = '88000000000';

  static const phoneHours = '8:00–23:00';

  /// Ник без @ — для https://t.me/<ник>.
  static const telegram = 'bitnebit_support';

  static Uri get phoneUri => Uri(scheme: 'tel', path: phoneDial);
  static Uri get telegramUri => Uri.https('t.me', '/$telegram');
}
