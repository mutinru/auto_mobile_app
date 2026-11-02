/// Ссылка на объявление — зеркало App\Support\ListingUrl на бекенде.
/// Сервер всё равно проверяет сам и отдаёт заказ с listing_host и
/// listing_site; здесь — мягкая проверка в форме и данные для моков.
library;

/// Известные площадки: домен → как назвать. Тот же список, что ListingUrl::SITES.
const listingSites = {
  'avito.ru': 'Авито',
  'auto.ru': 'Авто.ру',
  'drom.ru': 'Дром',
};

/// https://… или null, если это не ссылка: нет хоста с точкой, чужая
/// схема или пробелы внутри.
String? normalizeListingUrl(String raw) {
  var url = raw.trim();
  if (url.isEmpty || RegExp(r'\s').hasMatch(url)) return null;
  if (!RegExp(r'^[a-z][a-z0-9+.\-]*://', caseSensitive: false).hasMatch(url)) {
    url = 'https://$url';
  }
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
    return null;
  }
  final host = uri.host.replaceAll(RegExp(r'^\.+|\.+$'), '');
  return host.contains('.') ? url : null;
}

/// Хост без www./m.: avito.ru, moscow.drom.ru, example.com.
String? listingHost(String url) {
  final normalized = normalizeListingUrl(url);
  if (normalized == null) return null;
  return Uri.parse(
    normalized,
  ).host.toLowerCase().replaceFirst(RegExp(r'^(www|m)\.'), '');
}

/// «Авито» / «Авто.ру» / «Дром» или null для чужого сайта.
String? listingSite(String url) {
  final host = listingHost(url);
  if (host == null) return null;
  for (final entry in listingSites.entries) {
    if (host == entry.key || host.endsWith('.${entry.key}')) return entry.value;
  }
  return null;
}
