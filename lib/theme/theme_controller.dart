import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Выбранная тема — тёмная (по умолчанию) или светлая. Выбор переживает
/// перезапуск: лежит в том же защищённом хранилище, что и токен
/// ([AuthService]), — отдельный пакет настроек ради одного флага не тянем.
class ThemeController extends ChangeNotifier {
  ThemeController({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'app_theme';
  final FlutterSecureStorage _storage;

  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;
  bool get isLight => _mode == ThemeMode.light;

  /// Поднять сохранённый выбор. Зовётся до runApp, чтобы светлая тема не
  /// мигала тёмной на старте.
  Future<void> load() async {
    try {
      final saved = await _storage.read(key: _key);
      if (saved == 'light') _mode = ThemeMode.light;
    } catch (_) {
      // недоступное хранилище не должно ронять запуск — остаёмся на тёмной
    }
  }

  Future<void> setLight(bool light) async {
    final next = light ? ThemeMode.light : ThemeMode.dark;
    if (next == _mode) return;
    _mode = next;
    notifyListeners();
    try {
      await _storage.write(key: _key, value: light ? 'light' : 'dark');
    } catch (_) {
      // не сохранилось — тема всё равно сменится до перезапуска
    }
  }

  Future<void> toggle() => setLight(!isLight);
}

/// Отдаёт [ThemeController] вниз по дереву — переключателю темы на любом
/// экране. Подписывает зависимых на его изменения.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  /// null — над виджетом нет [ThemeScope] (виджет-тесты отдельных экранов).
  static ThemeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()?.notifier;
}
