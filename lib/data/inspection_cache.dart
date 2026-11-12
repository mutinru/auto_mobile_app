import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Копия осмотра на телефоне (ревью №12): без сети осмотр открывается из
/// неё, а не встаёт на «Нет связи». Хранит сырой JSON `GET /inspections/{id}`
/// и каталог дефектов; ответы мутаций правят в копии свою деталь.
///
/// Любой сбой диска (нет плагина в тестах, нет места) — копии просто нет:
/// без сети осмотр тогда не откроется, как раньше.
abstract final class InspectionCache {
  @visibleForTesting
  static Directory? debugRoot;

  static Future<Directory>? _root;

  static Future<Directory> _dir() => _root ??= () async {
    final base = debugRoot ?? await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/inspection_cache');
    await dir.create(recursive: true);
    return dir;
  }();

  @visibleForTesting
  static void debugReset() => _root = null;

  /// Записи — по одной за раз: деталь из ответа и свежий осмотр не
  /// перетирают друг друга.
  static Future<void> _writes = Future.value();

  static Future<T?> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (e) {
      debugPrint('Копия осмотра: $e');
      return null;
    }
  }

  static Future<File> _file(String name) async =>
      File('${(await _dir()).path}/$name.json');

  /// Шаг цепочки записей: [body] читает и пишет без гонок с другими.
  static Future<void> _serial(Future<void> Function() body) {
    final next = _writes.then((_) => _guard(body));
    _writes = next;
    return next;
  }

  static Future<void> _put(String name, Object json) async {
    final file = await _file(name);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(json), flush: true);
    await tmp.rename(file.path);
  }

  static Future<void> _write(String name, Object json) =>
      _serial(() => _put(name, json));

  static Future<Object?> _read(String name) => _guard<Object?>(() async {
    final file = await _file(name);
    if (!await file.exists()) return null;
    return jsonDecode(await file.readAsString());
  });

  static String _inspection(int id) => 'inspection_$id';

  /// Сырой `data` ответа `GET /inspections/{id}`.
  static Future<void> saveInspection(int id, Map<String, dynamic> data) =>
      _write(_inspection(id), data);

  static Future<Map<String, dynamic>?> loadInspection(int id) async =>
      await _read(_inspection(id)) as Map<String, dynamic>?;

  /// Ответ мутации — деталь целиком: подменить её в копии.
  static Future<void> savePanel(int id, Map<String, dynamic> panel) =>
      _serial(() async {
        final data = await _read(_inspection(id)) as Map<String, dynamic>?;
        final panels = data?['panels'] as List?;
        if (data == null || panels == null) return;
        final i = panels.indexWhere(
          (p) => (p as Map<String, dynamic>)['id'] == panel['id'],
        );
        if (i == -1) return;
        panels[i] = panel;
        await _put(_inspection(id), data);
      });

  /// Выход и удаление аккаунта: копии осмотров (с адресами и номерами
  /// машин) не должны пережить сессию. Очереди не трогаем — их отправит
  /// тот же исполнитель, когда войдёт снова.
  static Future<void> clear() => _serial(() async {
    final dir = await _dir();
    if (await dir.exists()) await dir.delete(recursive: true);
    _root = null;
  });

  static Future<void> saveDefects(List<dynamic> data, String? etag) =>
      _write('defects', {'data': data, 'etag': etag});

  static Future<({List<dynamic> data, String? etag})?> loadDefects() async {
    final json = await _read('defects') as Map<String, dynamic>?;
    if (json == null) return null;
    return (data: json['data'] as List<dynamic>, etag: json['etag'] as String?);
  }
}
