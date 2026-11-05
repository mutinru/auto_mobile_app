import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../navigation/section_nav.dart';

/// Последний «дом», выбранный на вопросе о намерении (QA 2026-11-05 №19):
/// вошедшему при запуске он открывается сразу, а «назад» всё равно ведёт к
/// вопросу. Раздел, открытый из профиля, дом не меняет — пишет только выбор
/// на вопросе. При выходе стирается: следующий пользователь начнёт с вопроса.
///
/// Лежит в том же защищённом хранилище, что токен и тема. Сбой хранилища
/// запуск не роняет — просто нет автоперехода.
class LastSection {
  /// Хранилище колбэками — чтобы тесты обходились без платформенного плагина.
  LastSection.withStorage({
    required this._read,
    required this._write,
    required this._delete,
  });

  factory LastSection.secure() {
    const storage = FlutterSecureStorage();
    return LastSection.withStorage(
      read: (key) => storage.read(key: key),
      write: (key, value) => storage.write(key: key, value: value),
      delete: (key) => storage.delete(key: key),
    );
  }

  static const _key = 'last_section';

  final Future<String?> Function(String key) _read;
  final Future<void> Function(String key, String value) _write;
  final Future<void> Function(String key) _delete;

  HomeSection? _value;

  /// Сохранённый раздел; null — не выбирали или стёрт.
  HomeSection? get value => _value;

  /// Поднять сохранённое. Зовётся до runApp, как тема.
  Future<void> load() async {
    try {
      final saved = await _read(_key);
      _value = HomeSection.values.where((s) => s.name == saved).firstOrNull;
    } catch (_) {
      _value = null;
    }
  }

  Future<void> save(HomeSection section) async {
    _value = section;
    try {
      await _write(_key, section.name);
    } catch (_) {
      // не сохранилось — до перезапуска помним в памяти
    }
  }

  Future<void> clear() async {
    _value = null;
    try {
      await _delete(_key);
    } catch (_) {
      // не стёрлось — после выхода автопереход всё равно не сработает:
      // гостю раздел не открывается
    }
  }
}
