import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/api_exception.dart';
import '../data/inspection_cache.dart';
import '../data/inspection_repository.dart';
import '../models/inspection_panel.dart';
import '../models/panel_condition.dart';
import '../widgets/api_error.dart';
import 'inspection_op.dart';

/// Что делает очередь сейчас.
enum OutboxState {
  /// Отправлять нечего.
  idle,

  /// Идёт отправка.
  sending,

  /// Сети нет или сервер не ответил — повтор по таймеру.
  waiting,

  /// Ждёт повода: сессия истекла, сборка устарела или очередь чужая.
  paused,
}

/// Что очередь сообщает стору осмотра.
sealed class OutboxEvent {
  const OutboxEvent();
}

/// Сервер принял действие и вернул деталь целиком.
class PanelConfirmed extends OutboxEvent {
  const PanelConfirmed(this.panel);
  final InspectionPanel panel;
}

/// Сервер отказал (403, 422…): действие снято, деталь надо перечитать.
class OpRejected extends OutboxEvent {
  const OpRejected(this.panelId, this.message);
  final String panelId;
  final String message;
}

/// Действие выполнено без детали в ответе (удалять было нечего) —
/// стору перечитать осмотр.
class RefreshNeeded extends OutboxEvent {
  const RefreshNeeded();
}

/// Очередь действий одного осмотра (ревью №12): исполнитель видит результат
/// сразу ([applyPending]), сервер получает действия по порядку, когда есть
/// сеть. Очередь лежит на диске (`<appSupport>/inspection_outbox/<id>.json`,
/// файлы — в `<id>/`) и переживает перезапуск; [InspectionOutbox.memory] —
/// без диска (тесты, мок).
class InspectionOutbox extends ChangeNotifier {
  InspectionOutbox._({
    required this.inspectionId,
    required this._repository,
    required this._dir,
    required this._currentUser,
  }) {
    ready = _load();
  }

  /// Очередь в памяти: для мок-репозитория и тестов.
  factory InspectionOutbox.memory(
    InspectionRepository repository, {
    int inspectionId = 0,
  }) => InspectionOutbox._(
    inspectionId: inspectionId,
    repository: repository,
    dir: null,
    currentUser: () async => null,
  );

  final int inspectionId;
  final InspectionRepository _repository;
  final Directory? _dir;
  final Future<int?> Function() _currentUser;

  /// Очередь поднята с диска.
  late final Future<void> ready;

  final _events = StreamController<OutboxEvent>.broadcast();
  Stream<OutboxEvent> get events => _events.stream;

  List<InspectionOp> _ops = [];
  int _nextId = 1;

  /// Чей осмотр: чужая очередь (вошёл другой) не отправляется.
  int? _owner;

  /// clientId загруженного снимка → серверный id: удаление снимка, который
  /// ушёл из очереди, но id которого экран ещё не знал.
  final Map<String, int> _uploaded = {};

  /// Действие, которое сейчас на сервере: его нельзя схлопнуть или отменить.
  int? _inFlight;

  OutboxState _state = OutboxState.idle;
  OutboxState get state => _state;

  List<InspectionOp> get pending => List.unmodifiable(_ops);
  int get pendingCount => _ops.length;

  Timer? _retry;
  int _failures = 0;

  /// Пауза перед повтором: 2, 4, 8 … 60 с.
  @visibleForTesting
  static Duration Function(int failures) retryDelay = (n) =>
      Duration(seconds: min(60, 1 << min(n, 6)));

  File? get _file {
    final dir = _dir;
    return dir == null ? null : File('${dir.path}/$inspectionId.json');
  }

  Directory? get _media {
    final dir = _dir;
    return dir == null ? null : Directory('${dir.path}/$inspectionId');
  }

  Future<void> _load() async {
    final file = _file;
    try {
      if (file == null || !await file.exists()) return;
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _owner = json['user_id'] as int?;
      _nextId = json['next_id'] as int? ?? 1;
      _ops = [
        for (final o in json['ops'] as List)
          InspectionOp.fromJson(o as Map<String, dynamic>),
      ];
      _uploaded.addAll(
        (json['uploaded'] as Map<String, dynamic>? ?? const {}).map(
          (k, v) => MapEntry(k, v as int),
        ),
      );
    } catch (e) {
      // битый файл не должен ронять осмотр: очередь начнётся заново
      debugPrint('Очередь осмотра $inspectionId не прочитана: $e');
    }
  }

  Future<void> _save() async {
    final file = _file;
    if (file == null) return;
    try {
      if (_ops.isEmpty) {
        if (await file.exists()) await file.delete();
        final media = _media;
        if (media != null && await media.exists()) {
          await media.delete(recursive: true);
        }
        _uploaded.clear();
        return;
      }
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(
        jsonEncode({
          'user_id': _owner,
          'next_id': _nextId,
          'ops': [for (final op in _ops) op.toJson()],
          'uploaded': _uploaded,
        }),
        flush: true,
      );
      await tmp.rename(file.path);
    } catch (e) {
      debugPrint('Очередь осмотра $inspectionId не сохранена: $e');
    }
  }

  /// Файл снимка или записи — в папку очереди: временные файлы камеры и
  /// диктофона система может стереть до отправки.
  Future<String> _keep(String path, String name) async {
    final media = _media;
    if (media == null) return path;
    try {
      await media.create(recursive: true);
      final dot = path.lastIndexOf('.');
      final ext = dot > path.lastIndexOf('/') ? path.substring(dot) : '';
      return (await File(path).copy('${media.path}/$name$ext')).path;
    } catch (e) {
      debugPrint('Файл не скопирован в очередь: $e');
      return path;
    }
  }

  Future<void> _drop(String? path) async {
    final media = _media;
    if (path == null || media == null || !path.startsWith(media.path)) return;
    try {
      await File(path).delete();
    } catch (_) {}
  }

  bool _removable(InspectionOp op) => op.id != _inFlight;

  Future<void> _push(InspectionOp Function(int id) build) async {
    await ready;
    _owner ??= await _currentUser();
    _ops.add(build(_nextId++));
    await _save();
    notifyListeners();
  }

  /// Снять ещё не отправленные действия, подходящие под [test].
  Future<void> _removeWhere(bool Function(InspectionOp op) test) async {
    final gone = _ops.where((op) => _removable(op) && test(op)).toList();
    if (gone.isEmpty) return;
    _ops.removeWhere(gone.contains);
    for (final op in gone) {
      await _drop(op.file);
    }
  }

  // --- действия -------------------------------------------------------

  Future<void> setCondition(String panelId, PanelCondition condition) async {
    await ready;
    await _removeWhere((op) => op is SetConditionOp && op.panelId == panelId);
    await _push(
      (id) => SetConditionOp(id: id, panelId: panelId, condition: condition),
    );
  }

  Future<void> setDefect(
    String panelId,
    int defectId,
    String label, {
    required bool on,
  }) async {
    await ready;
    await _removeWhere(
      (op) =>
          op is SetDefectOp && op.panelId == panelId && op.defectId == defectId,
    );
    await _push(
      (id) => SetDefectOp(
        id: id,
        panelId: panelId,
        defectId: defectId,
        label: label,
        on: on,
      ),
    );
  }

  Future<void> addPhoto(
    String panelId,
    String path, {
    PhotoSource source = PhotoSource.camera,
    String? takenAt,
  }) async {
    await ready;
    final clientId = newClientId();
    final kept = await _keep(path, clientId);
    await _push(
      (id) => AddPhotoOp(
        id: id,
        panelId: panelId,
        clientId: clientId,
        path: kept,
        source: source,
        takenAt: takenAt,
      ),
    );
  }

  /// Удалить снимок. Ещё не отправленный — просто убрать из очереди.
  Future<void> deletePhoto(String panelId, PanelPhoto photo) async {
    await ready;
    final clientId = photo.clientId;
    if (photo.isPending && clientId != null) {
      final queued = _ops.whereType<AddPhotoOp>().where(
        (op) => op.clientId == clientId,
      );
      if (queued.isNotEmpty && _removable(queued.first)) {
        await _removeWhere((op) => op is AddPhotoOp && op.clientId == clientId);
        await _save();
        notifyListeners();
        return;
      }
    }
    await _push(
      (id) => DeletePhotoOp(
        id: id,
        panelId: panelId,
        photoId: photo.id == 0 ? null : photo.id,
        clientId: photo.id == 0 ? clientId : null,
      ),
    );
  }

  Future<void> setAudio(String panelId, String path, int seconds) async {
    await ready;
    await _removeWhere(
      (op) =>
          (op is SetAudioOp || op is DeleteAudioOp) && op.panelId == panelId,
    );
    final kept = await _keep(path, 'audio_${panelId}_$_nextId');
    await _push(
      (id) =>
          SetAudioOp(id: id, panelId: panelId, path: kept, seconds: seconds),
    );
  }

  Future<void> deleteAudio(String panelId) async {
    await ready;
    await _removeWhere(
      (op) =>
          (op is SetAudioOp || op is DeleteAudioOp) && op.panelId == panelId,
    );
    await _push((id) => DeleteAudioOp(id: id, panelId: panelId));
  }

  // --- отправка -------------------------------------------------------

  Future<void>? _flushing;

  /// Отправить очередь. Параллельные вызовы делят один проход; проход
  /// кончается, когда очередь пуста, сети нет (повтор по таймеру) или
  /// очередь на паузе.
  Future<void> flush() =>
      _flushing ??= _run().whenComplete(() => _flushing = null);

  Future<void> _run() async {
    await ready;
    _retry?.cancel();
    if (_ops.isEmpty) return _setState(OutboxState.idle);

    final user = await _currentUser();
    _owner ??= user;
    if (_owner != null && user != null && _owner != user) {
      return _setState(OutboxState.paused);
    }

    _setState(OutboxState.sending);
    while (_ops.isNotEmpty) {
      final op = _ops.first;
      _inFlight = op.id;
      final outcome = await _send(op);
      _inFlight = null;
      switch (outcome) {
        case _Done(:final panel):
          _failures = 0;
          await _finish(op);
          _events.add(
            panel == null ? const RefreshNeeded() : PanelConfirmed(panel),
          );
        case _Rejected(:final message):
          _failures = 0;
          await _finish(op);
          _events.add(OpRejected(op.panelId, message));
        case _Retry():
          _failures++;
          _retry = Timer(retryDelay(_failures), flush);
          return _setState(OutboxState.waiting);
        case _Pause():
          return _setState(OutboxState.paused);
      }
    }
    _setState(OutboxState.idle);
  }

  Future<void> _finish(InspectionOp op) async {
    _ops.removeWhere((o) => o.id == op.id);
    await _drop(op.file);
    await _save();
    notifyListeners();
  }

  void _setState(OutboxState state) {
    if (_state == state) return;
    _state = state;
    notifyListeners();
  }

  Future<_Outcome> _send(InspectionOp op) async {
    try {
      final panel = switch (op) {
        SetConditionOp(:final panelId, :final condition) =>
          await _repository.updateCondition(panelId, condition),
        SetDefectOp(:final panelId, :final defectId, :final on) =>
          await _repository.setDefect(panelId, defectId, on: on),
        AddPhotoOp(
          :final panelId,
          :final path,
          :final clientId,
          :final source,
          :final takenAt,
        ) =>
          await _uploadPhoto(panelId, path, clientId, source, takenAt),
        DeletePhotoOp(:final photoId, :final clientId) => await _deletePhoto(
          photoId ?? _uploaded[clientId],
        ),
        SetAudioOp(:final panelId, :final path, :final seconds) =>
          await _repository.uploadAudioNote(panelId, path, seconds),
        DeleteAudioOp(:final panelId) => await _repository.deleteAudioNote(
          panelId,
        ),
      };
      return _Done(panel);
    } catch (e) {
      return _classify(op, e);
    }
  }

  Future<InspectionPanel> _uploadPhoto(
    String panelId,
    String path,
    String clientId,
    PhotoSource source,
    String? takenAt,
  ) async {
    final panel = await _repository.uploadPhoto(
      panelId,
      path,
      clientId: clientId,
      source: source,
      takenAt: takenAt,
    );
    for (final p in panel.photos) {
      if (p.clientId == clientId) _uploaded[clientId] = p.id;
    }
    return panel;
  }

  /// Снимок не узнали (ответ загрузки потерялся) — удалять нечего, стор
  /// перечитает осмотр.
  Future<InspectionPanel?> _deletePhoto(int? photoId) async =>
      photoId == null ? null : await _repository.deletePhoto(photoId);

  _Outcome _classify(InspectionOp op, Object e) {
    if (isNetworkError(e)) return const _Retry();
    if (e is ApiException) {
      final status = e.statusCode;
      if (status == 401 || status == 426) return const _Pause();
      if (status == 408 || status == 429 || status >= 500) {
        return const _Retry();
      }
      // удалять уже нечего — цель достигнута
      if (status == 404 && (op is DeletePhotoOp || op is DeleteAudioOp)) {
        return const _Done(null);
      }
      return _Rejected(apiErrorText(e));
    }
    if (e is FileSystemException) {
      return const _Rejected('файл не найден на телефоне — снимите ещё раз');
    }
    return _Rejected(apiErrorText(e));
  }

  @override
  void dispose() {
    _retry?.cancel();
    _events.close();
    super.dispose();
  }
}

sealed class _Outcome {
  const _Outcome();
}

class _Done extends _Outcome {
  const _Done(this.panel);
  final InspectionPanel? panel;
}

class _Rejected extends _Outcome {
  const _Rejected(this.message);
  final String message;
}

class _Retry extends _Outcome {
  const _Retry();
}

class _Pause extends _Outcome {
  const _Pause();
}

/// Очереди всех осмотров — одна на приложение (`main.dart`). Держит их
/// живыми, пока экраны закрыты: отправка идёт в фоне и после выхода из
/// осмотра, а при запуске поднимаются очереди, оставшиеся с прошлого раза.
/// Осмотр, к которому можно вернуться без сети (карточка на главной
/// исполнителя): после перезапуска офлайн до него иначе не дойти — заказы
/// грузятся с сервера.
class ResumableInspection {
  const ResumableInspection({
    required this.inspectionId,
    required this.title,
    required this.pendingCount,
    required this.lastOpened,
  });

  final int inspectionId;

  /// «Skoda Octavia 2018» из копии осмотра; null — копии нет.
  final String? title;
  final int pendingCount;

  /// Последний открытый осмотр (может быть и без несохранённого).
  final bool lastOpened;
}

class InspectionOutboxes extends ChangeNotifier {
  InspectionOutboxes({
    required this.repositoryFor,
    required this.currentUser,
    this._root,
  });

  /// Глобальный реестр; null — очередь только в памяти (тесты, мок).
  static InspectionOutboxes? instance;

  final InspectionRepository Function(int inspectionId) repositoryFor;
  final Future<int?> Function() currentUser;
  final Directory? _root;
  final _outboxes = <int, InspectionOutbox>{};

  Future<Directory>? _dir;

  Future<Directory> _directory() => _dir ??= () async {
    final base = _root ?? await getApplicationSupportDirectory();
    return Directory('${base.path}/inspection_outbox');
  }();

  /// Очередь осмотра; без диска (нет плагина) — в памяти.
  InspectionOutbox forInspection(int inspectionId) =>
      _outboxes[inspectionId] ??= _open(inspectionId)..addListener(_changed);

  int? _lastOpened;

  /// Исполнитель открыл осмотр: без сети к нему вернёт карточка на главной.
  Future<void> markOpened(int inspectionId) async {
    _lastOpened = inspectionId;
    final dir = _rootSync;
    if (dir != null) {
      try {
        await dir.create(recursive: true);
        await File('${dir.path}/last_opened').writeAsString('$inspectionId');
      } catch (_) {}
    }
    _changed();
  }

  /// Выход: последний открытый осмотр — не для следующего вошедшего.
  Future<void> forgetLastOpened() async {
    _lastOpened = null;
    final dir = _rootSync;
    if (dir != null) {
      try {
        final file = File('${dir.path}/last_opened');
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    _changed();
  }

  List<ResumableInspection> _resumable = const [];

  /// Осмотры с несохранёнными изменениями и последний открытый.
  List<ResumableInspection> get resumable => _resumable;

  int _generation = 0;

  /// Пересобрать [resumable]: заголовки — из копий осмотров (диск).
  void _changed() {
    final generation = ++_generation;
    unawaited(() async {
      final ids = {
        for (final o in _outboxes.values)
          if (o.pendingCount > 0) o.inspectionId,
        ?_lastOpened,
      };
      final list = <ResumableInspection>[];
      for (final id in ids) {
        final car = (await InspectionCache.loadInspection(id))?['car'];
        final title = car is Map<String, dynamic>
            ? [
                car['brand'],
                car['model'],
                car['year'],
              ].whereType<Object>().join(' ')
            : null;
        list.add(
          ResumableInspection(
            inspectionId: id,
            title: title,
            pendingCount: _outboxes[id]?.pendingCount ?? 0,
            lastOpened: id == _lastOpened,
          ),
        );
      }
      if (generation != _generation) return;
      _resumable = list;
      notifyListeners();
    }());
  }

  InspectionOutbox _open(int inspectionId) {
    final repository = repositoryFor(inspectionId);
    final dir = _rootSync;
    return InspectionOutbox._(
      inspectionId: inspectionId,
      repository: repository,
      dir: dir,
      currentUser: currentUser,
    );
  }

  Directory? _rootSync;

  /// Найти папку очередей до первой очереди: [forInspection] синхронный.
  Future<void> init() async {
    try {
      _rootSync = await _directory();
      final last = File('${_rootSync!.path}/last_opened');
      if (await last.exists()) {
        _lastOpened = int.tryParse((await last.readAsString()).trim());
      }
    } catch (e) {
      debugPrint('Очереди осмотров — только в памяти: $e');
    }
  }

  /// Поднять очереди, оставшиеся с прошлого запуска, и отправить их.
  Future<void> resumeAll() async {
    final dir = _rootSync;
    if (dir != null) {
      try {
        if (await dir.exists()) {
          await for (final entry in dir.list()) {
            final name = entry.uri.pathSegments.last;
            final id = int.tryParse(name.replaceFirst('.json', ''));
            if (entry is File && name.endsWith('.json') && id != null) {
              forInspection(id);
            }
          }
        }
      } catch (e) {
        debugPrint('Очереди осмотров не прочитаны: $e');
      }
    }
    _changed();
    flushAll();
  }

  void flushAll() {
    for (final outbox in _outboxes.values) {
      unawaited(outbox.flush());
    }
  }
}
