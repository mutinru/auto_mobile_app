import 'package:geolocator/geolocator.dart';

/// Координаты устройства. Абстракция — чтобы виджет-тесты не трогали
/// платформенный плагин.
abstract class LocationService {
  /// (широта, долгота) или null: геолокация выключена, доступ не дали,
  /// не успели за таймаут. Не бросает.
  Future<(double, double)?> current();
}

/// Грубая точность (ACCESS_COARSE_LOCATION): нужен город, а не подъезд —
/// так быстрее, дешевле для батареи, и разрешение пугает меньше.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  /// Последняя известная точка старше этого — не доверяем, ждём новую.
  static const _maxAge = Duration(minutes: 30);

  @override
  Future<(double, double)?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      // последняя известная точка приходит мгновенно, для города её хватает —
      // если она свежая: после перелёта в кеше лежит прошлый город
      final last = await Geolocator.getLastKnownPosition();
      final fresh = last != null &&
          DateTime.now().difference(last.timestamp) < _maxAge;
      final position = fresh
          ? last
          : await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 10),
            ),
          );
      return (position.latitude, position.longitude);
    } catch (_) {
      // таймаут, отказ платформы — для подсказки города это не ошибка
      return null;
    }
  }
}
