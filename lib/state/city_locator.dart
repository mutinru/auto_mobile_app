import '../data/city_repository.dart';
import '../data/location_service.dart';
import '../models/city.dart';

/// Город пользователя по геопозиции — подсказка для форм и фильтров,
/// и сама точка — для расстояния до заказа.
/// Один на приложение (см. main.dart): удачный результат запоминается на
/// всю сессию, чтобы не дёргать GPS и запрос разрешения на каждом экране.
class CityLocator {
  CityLocator(this._cities, this._location);

  final CityRepository _cities;
  final LocationService _location;

  Future<City?>? _detected;
  Future<(double, double)?>? _position;

  /// Ближайший город или null. Не бросает. Неудачу не запоминаем: следующий
  /// экран попробует снова (например, когда пользователь включит GPS).
  Future<City?> detect() {
    return _detected ??= _resolve().then((city) {
      if (city == null) _detected = null;
      return city;
    });
  }

  /// Фоновый прогрев после входа: город готов раньше, чем его спросит
  /// первый экран. Только если доступ к геопозиции уже дан — запрос
  /// разрешения остаётся за экраном, где город нужен (окно на старте без
  /// объяснения чаще получает отказ). Не бросает.
  Future<void> warmUp() async {
    if (await _location.isGranted()) await detect();
  }

  /// Точка устройства — для расстояния до заказа. Не бросает; неудачу,
  /// как и у [detect], не запоминаем.
  Future<(double, double)?> position() {
    return _position ??= _location.current().then((point) {
      if (point == null) _position = null;
      return point;
    });
  }

  /// Почему [detect] не дал города — для подсказки «что сделать».
  Future<LocationProblem?> problem() => _location.problem();

  Future<void> openSettings(LocationProblem problem) =>
      _location.openSettings(problem);

  Future<City?> _resolve() async {
    try {
      final point = await position();
      if (point == null) return null;
      return await _cities.nearest(point.$1, point.$2);
    } catch (_) {
      return null;
    }
  }
}
