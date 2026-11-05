import '../models/order.dart';

/// Ссылки «маршрут до осмотра» во внешний навигатор (бэклог №28), по
/// порядку попыток; пусто — открывать нечего.
///
/// Первая — `geo:`: на Android система предложит любой навигатор (Яндекс,
/// 2ГИС, Google). Запасная — Яндекс Карты по https: откроются приложением
/// или в браузере (нет приложения под `geo:`, iOS).
///
/// По координатам — только если точка — сам дом ([Order.hasExactPoint]):
/// у адреса, введённого руками, точка — центр города, маршрут по ней увёл
/// бы не туда. Тогда — поиском по тексту адреса.
List<Uri> routeLinks(Order order) {
  final address = order.fullAddress;
  if (order.hasExactPoint) {
    final point = '${order.lat},${order.lon}';
    final label = address == null ? '' : '($address)';
    return [
      Uri.parse('geo:$point?q=${Uri.encodeQueryComponent('$point$label')}'),
      Uri.https('yandex.ru', '/maps/', {'rtext': '~$point', 'rtt': 'auto'}),
    ];
  }
  if (address == null) return const [];
  return [
    Uri.parse('geo:0,0?q=${Uri.encodeQueryComponent(address)}'),
    Uri.https('yandex.ru', '/maps/', {'text': address}),
  ];
}
