import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../util/client_id.dart';

/// Ключи повтора мутаций (ревью №17): `Idempotency-Key` для запросов,
/// исход которых неизвестен. Запрос ушёл, а ответ не пришёл (таймаут, обрыв,
/// 5xx) — ключ остаётся, и та же отправка того же запроса (кнопка
/// «Повторить», повторное нажатие, очередь осмотра, даже после перезапуска)
/// уйдёт с тем же ключом. Сервер (`App\Http\Middleware\Idempotent`) тогда
/// отдаст сохранённый ответ, а не создаст второй заказ, отклик или
/// сообщение. Пришёл ответ — ключ забыт, следующий такой же запрос —
/// новое действие.
///
/// «Тот же запрос» — та же подпись ([signature]): пользователь, метод, путь,
/// тело. На диске — только sha256 подписи: в телах реквизиты и телефоны.
///
/// Ключ живёт [ttl] — меньше суток, которые сервер хранит ответ: старше
/// сервер выполнил бы повтор заново.
///
/// Сбой диска (нет плагина в тестах, нет места) — ключи только в памяти.
class IdempotencyKeys {
  IdempotencyKeys._(this._persistent, this._root, DateTime Function()? now)
    : _now = now ?? DateTime.now;

  /// Ключи в памяти: тесты и мок.
  factory IdempotencyKeys.memory({DateTime Function()? now}) =>
      IdempotencyKeys._(false, null, now);

  /// Ключи в файле `<appSupport>/idempotency_keys.json` ([root] — для тестов).
  factory IdempotencyKeys.disk({Directory? root, DateTime Function()? now}) =>
      IdempotencyKeys._(true, root, now);

  /// Общие на приложение: `ApiClient` создаётся на каждый репозиторий.
  /// На диск их переключает `main()`; по умолчанию — память: в виджет-тестах
  /// нет плагина, а диск под подменённым временем не отвечает.
  static IdempotencyKeys instance = IdempotencyKeys.memory();

  /// Заголовок запроса — зеркало `Idempotent::HEADER`.
  static const header = 'Idempotency-Key';

  /// Сервер хранит ответ сутки (`IdempotencyKey::TTL_HOURS`).
  static const ttl = Duration(hours: 12);

  /// Больше незавершённых запросов не бывает; старые вытесняются.
  static const maxEntries = 100;

  final bool _persistent;
  final Directory? _root;
  final DateTime Function() _now;
  Future<File?>? _fileFuture;

  /// sha256 подписи → ключ и когда он выдан.
  final _entries = <String, ({String key, DateTime at})>{};
  // Фьючерсы чтения и записи живут, только пока идёт работа с диском:
  // завершённый фьючерс, сохранённый в общем `instance`, будил бы
  // ожидающих в зоне, где его создали (в тестах — зона прошлого теста).
  bool _loaded = false;
  Future<void>? _loading;
  Future<void>? _writes;

  /// Подпись запроса. У формы с файлами — поля и для файлов имя поля, имя
  /// и длина (содержимое сверяет сервер).
  static String signature({
    required int? userId,
    required String method,
    required String path,
    String? body,
    Map<String, String> fields = const {},
    List<({String field, String? filename, int length})> files = const [],
  }) {
    final sortedFields = fields.keys.toList()..sort();
    final canonical = jsonEncode([
      userId,
      method,
      path,
      body,
      [
        for (final k in sortedFields) [k, fields[k]],
      ],
      [
        for (final f in files) [f.field, f.filename, f.length],
      ],
    ]);
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  /// Ключ для запроса с подписью [signature]: прежний, если его исход
  /// неизвестен, иначе новый.
  Future<String> keyFor(String signature) async {
    await _load();
    _expire();
    final live = _entries[signature];
    if (live != null) return live.key;

    final key = newClientId();
    _entries[signature] = (key: key, at: _now());
    while (_entries.length > maxEntries) {
      final oldest = _entries.entries
          .reduce((a, b) => a.value.at.isBefore(b.value.at) ? a : b)
          .key;
      _entries.remove(oldest);
    }
    await _save();
    return key;
  }

  /// Исход известен (сервер ответил) — ключ больше не нужен.
  Future<void> settle(String signature) async {
    await _load();
    if (_entries.remove(signature) != null) await _save();
  }

  /// Выход: ключи прежнего пользователя не нужны.
  Future<void> clear() async {
    await _load();
    _entries.clear();
    await _save();
  }

  @visibleForTesting
  int get length => _entries.length;

  void _expire() {
    final border = _now().subtract(ttl);
    _entries.removeWhere((_, v) => v.at.isBefore(border));
  }

  /// Файл ключей; null — только память (нет плагина, сбой диска). Сбой
  /// пишется в лог один раз, а не на каждый запрос.
  Future<File?> _file() => _fileFuture ??= () async {
    if (!_persistent) return null;
    try {
      final base = _root ?? await getApplicationSupportDirectory();
      return File('${base.path}/idempotency_keys.json');
    } catch (e) {
      debugPrint('Ключи повтора — только в памяти: $e');
      return null;
    }
  }();

  Future<void> _load() async {
    if (!_persistent || _loaded) return;
    await (_loading ??= _read().whenComplete(() {
      _loaded = true;
      _loading = null;
    }));
  }

  Future<void> _read() async {
    try {
      final file = await _file();
      if (file == null || !await file.exists()) return;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return;
      for (final e in json.entries) {
        final v = e.value;
        if (v is! Map<String, dynamic>) continue;
        final key = v['key'];
        final at = DateTime.tryParse('${v['at']}');
        if (key is String && at != null) _entries[e.key] = (key: key, at: at);
      }
    } catch (e) {
      debugPrint('Ключи повтора: $e');
    }
  }

  /// Записи — по одной за раз, последняя побеждает.
  Future<void> _save() async {
    if (!_persistent) return;
    final snapshot = {
      for (final e in _entries.entries)
        e.key: {'key': e.value.key, 'at': e.value.at.toIso8601String()},
    };
    final previous = _writes;
    final next = () async {
      if (previous != null) await previous;
      await _write(snapshot);
    }();
    _writes = next;
    await next;
    if (identical(_writes, next)) _writes = null;
  }

  Future<void> _write(Map<String, Object> snapshot) async {
    try {
      final file = await _file();
      if (file == null) return;
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(snapshot), flush: true);
      await tmp.rename(file.path);
    } catch (e) {
      debugPrint('Ключи повтора: $e');
    }
  }
}
