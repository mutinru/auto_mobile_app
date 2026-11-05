import 'package:geolocator/geolocator.dart';

/// Почему геопозиции нет — чтобы сказать пользователю, что сделать
/// (QA №20).
enum LocationProblem {
  /// Геолокация на телефоне выключена — включается в настройках системы.
  serviceOff,

  /// Доступ не дали, но спросить можно снова.
  denied,

  /// Доступ запрещён навсегда — только настройки приложения.
  deniedForever,
}

/// Координаты устройства. Абстракция — чтобы виджет-тесты не трогали
/// платформенный плагин.
abstract class LocationService {
  /// (широта, долгота) или null: геолокация выключена, доступ не дали,
  /// не успели за таймаут. Не бросает.
  Future<(double, double)?> current();

  /// Геолокация включена и доступ уже дан. Разрешение **не** спрашивает —
  /// для фонового прогрева города, где окно запроса было бы некстати.
  /// Не бросает.
  Future<bool> isGranted();

  /// Почему геопозиции нет; null — с доступом всё в порядке (значит,
  /// таймаут или сеть). Разрешение **не** спрашивает. Не бросает.
  Future<LocationProblem?> problem();

  /// Открыть настройки, где [problem] решается: системные для
  /// выключенной геолокации, приложения — для запрета. Не бросает.
  Future<void> openSettings(LocationProblem problem);
}

/// Грубая точность (ACCESS_COARSE_LOCATION): нужен город, а не подъезд —
/// так быстрее, дешевле для батареи, и разрешение пугает меньше.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  /// Последняя известная точка старше этого — не доверяем, ждём новую.
  static const _maxAge = Duration(minutes: 30);

  @override
  Future<bool> isGranted() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<LocationProblem?> problem() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationProblem.serviceOff;
      }
      return switch (await Geolocator.checkPermission()) {
        LocationPermission.denied => LocationProblem.denied,
        LocationPermission.deniedForever => LocationProblem.deniedForever,
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> openSettings(LocationProblem problem) async {
    try {
      switch (problem) {
        case LocationProblem.serviceOff:
          await Geolocator.openLocationSettings();
        case LocationProblem.denied:
        case LocationProblem.deniedForever:
          await Geolocator.openAppSettings();
      }
    } catch (_) {
      // настройки не открылись — заметка в шторке всё равно объясняет, что делать
    }
  }

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
      final fresh =
          last != null && DateTime.now().difference(last.timestamp) < _maxAge;
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
