import '../data/city_repository.dart';
import '../data/location_service.dart';
import '../models/city.dart';

/// Город пользователя по геопозиции — подсказка для форм и фильтров.
/// Один на приложение (см. main.dart): удачный результат запоминается на
/// всю сессию, чтобы не дёргать GPS и запрос разрешения на каждом экране.
class CityLocator {
  CityLocator(this._cities, this._location);

  final CityRepository _cities;
  final LocationService _location;

  Future<City?>? _detected;

  /// Ближайший город или null. Не бросает. Неудачу не запоминаем: следующий
  /// экран попробует снова (например, когда пользователь включит GPS).
  Future<City?> detect() {
    return _detected ??= _resolve().then((city) {
      if (city == null) _detected = null;
      return city;
    });
  }

  Future<City?> _resolve() async {
    try {
      final point = await _location.current();
      if (point == null) return null;
      return await _cities.nearest(point.$1, point.$2);
    } catch (_) {
      return null;
    }
  }
}
