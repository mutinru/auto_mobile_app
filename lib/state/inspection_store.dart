import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/inspection_repository.dart';
import '../models/car.dart';
import '../models/defect_def.dart';
import '../models/inspection_panel.dart';
import '../models/panel_condition.dart';
import '../models/panel_status.dart';
import '../widgets/api_error.dart';
import 'inspection_op.dart';
import 'inspection_outbox.dart';

/// Единственный источник правды для экрана осмотра в рамках сессии.
///
/// Детали — те, что подтвердил сервер, плюс действия очереди поверх
/// ([applyPending]). Мутации не ждут сеть (ревью №12): действие ложится в
/// [InspectionOutbox] и сразу видно, очередь отправит его, когда будет
/// связь, а ответ сервера (деталь целиком) заменит локальный расчёт.
/// Отказ сервера приходит в [rejections].
class InspectionStore extends ChangeNotifier {
  InspectionStore(
    this._repository, {
    this.readOnly = false,
    InspectionOutbox? outbox,
  }) : _outbox = readOnly
           ? null
           : (outbox ?? InspectionOutbox.memory(_repository)) {
    _outbox?.addListener(_onOutboxChanged);
    _events = _outbox?.events.listen(_onOutboxEvent);
  }

  final InspectionRepository _repository;

  /// Осмотр только для просмотра: заказчик подбора смотрит кандидата, сервер
  /// запись ему не разрешит (403). Экраны гасят все мутации.
  final bool readOnly;

  final InspectionOutbox? _outbox;
  StreamSubscription<OutboxEvent>? _events;

  Car? _car;

  /// Детали, как их отдал сервер (или копия на телефоне).
  List<InspectionPanel> _confirmed = const [];

  /// [_confirmed] с действиями очереди поверх — то, что видит исполнитель.
  List<InspectionPanel> _panels = const [];
  List<DefectDef> _defectCatalog = const [];

  /// код пункта -> метки доступных дефектов в порядке каталога; строится
  /// один раз при [load], экран детали читает его на каждой перерисовке.
  Map<String, List<String>> _defectsByPanel = const {};
  bool _loading = false;
  String? _loadError;
  bool _offline = false;

  final _rejections = StreamController<String>.broadcast();

  /// «Не сохранилось: <деталь> — <причина>»: сервер отказал действию из
  /// очереди (заказчик уже оплатил отчёт, лимит фото). Экран показывает
  /// снекбар; стор сам перечитывает осмотр.
  Stream<String> get rejections => _rejections.stream;

  /// Осмотр открыт из копии на телефоне: сети не было.
  bool get isOffline => _offline;

  /// Сколько действий ещё не на сервере.
  int get pendingCount => _outbox?.pendingCount ?? 0;

  /// Очередь ждёт сеть (последняя попытка не прошла).
  bool get isWaitingForNetwork => _outbox?.state == OutboxState.waiting;

  /// Отчёт можно отправлять: всё заполнено и уже на сервере.
  bool get canSendReport => isReportComplete && pendingCount == 0;

  void _recompute() {
    _panels = applyPending(_confirmed, _outbox?.pending ?? const []);
  }

  void _onOutboxChanged() {
    _recompute();
    notifyListeners();
  }

  void _onOutboxEvent(OutboxEvent event) {
    switch (event) {
      case PanelConfirmed(:final panel):
        final i = _confirmed.indexWhere((p) => p.id == panel.id);
        if (i == -1) return;
        _confirmed = [..._confirmed]..[i] = panel;
        _onOutboxChanged();
        // сервер ответил — сеть вернулась: копию заменит свежий осмотр
        if (_offline) unawaited(_refresh());
      case OpRejected(:final panelId, :final message):
        final name = _confirmed
            .where((p) => p.id == panelId)
            .map((p) => p.name)
            .firstOrNull;
        _rejections.add(
          name == null
              ? 'Не сохранилось: $message'
              : 'Не сохранилось: $name — $message',
        );
        unawaited(_refresh());
      case RefreshNeeded():
        unawaited(_refresh());
    }
  }

  /// Перечитать осмотр с сервера без спиннера (плашка «показана
  /// сохранённая копия»). Сети всё ещё нет — останется копия.
  Future<void> refresh() => _refresh();

  /// Тихо перечитать осмотр (без спиннера): после отказа сервера.
  Future<void> _refresh() async {
    try {
      final snapshot = await _repository.fetchInspection();
      if (snapshot.offline) return;
      _car = snapshot.car;
      _confirmed = snapshot.panels;
      _offline = false;
      _onOutboxChanged();
    } catch (_) {
      // не вышло — останется то, что было
    }
  }

  @override
  void dispose() {
    _outbox?.removeListener(_onOutboxChanged);
    _events?.cancel();
    _rejections.close();
    super.dispose();
  }

  Car? get car => _car;

  /// Текст ошибки загрузки — без него экран остался бы на спиннере:
  /// гейт там ещё и на car == null.
  String? get loadError => _loadError;
  List<InspectionPanel> get panels => List.unmodifiable(_panels);

  /// Чипы дефектов для пункта: доступные ему плюс уже отмеченные вне списка
  /// (каталог могли поменять после отметки — снять такой дефект сервер даёт).
  List<String> defectLabelsFor(InspectionPanel panel) {
    final allowed = _defectsByPanel[panel.id] ?? const <String>[];
    final stale = panel.defects.where((d) => !allowed.contains(d));
    return stale.isEmpty ? allowed : [...allowed, ...stale];
  }

  bool get isLoading => _loading;

  int get totalCount => _panels.length;
  int get evaluatedCount =>
      _panels.where((p) => p.status != PanelStatus.none).length;
  int get remainingCount => totalCount - evaluatedCount;

  /// Первый неоценённый пункт в серверном порядке (кузов, затем extra) —
  /// с него схема предлагает начать или продолжить осмотр.
  InspectionPanel? get firstUnrated {
    for (final p in _panels) {
      if (p.status == PanelStatus.none) return p;
    }
    return null;
  }

  /// Оценённые пункты, которым для отчёта не хватает фото или дефекта.
  List<InspectionPanel> get incompletePanels =>
      _panels.where((p) => p.isIncomplete).toList();

  /// Куда вести исполнителя дальше: сначала неоценённые, потом недоделанные.
  InspectionPanel? get firstIncomplete {
    final unrated = firstUnrated;
    if (unrated != null) return unrated;
    for (final p in _panels) {
      if (p.isIncomplete) return p;
    }
    return null;
  }

  /// Что мешает отправить отчёт, в серверном порядке: неоценённые и
  /// недозаполненные пункты. По нему строятся шторка «Осталось исправить»
  /// и счётчик режима исправления.
  List<InspectionPanel> get problems => _panels
      .where((p) => p.status == PanelStatus.none || p.isIncomplete)
      .toList();

  /// Обычный проход «Дальше» дошёл до конца — последний пункт оценён.
  /// Дальше схема ведёт не по порядку, а к списку того, что осталось.
  bool get passFinished =>
      _panels.isNotEmpty && _panels.last.status != PanelStatus.none;

  /// Отчёт можно отправлять: всё оценено и дозаполнено (то же проверит сервер).
  bool get isReportComplete =>
      remainingCount == 0 && !_panels.any((p) => p.isIncomplete);

  /// Ошибка не пробрасывается — она в [loadError], экран рисует её с
  /// «Повторить» вместо вечного спиннера.
  Future<void> load() async {
    _loading = true;
    _loadError = null;
    notifyListeners();
    try {
      await _outbox?.ready;
      final results = await Future.wait([
        _repository.fetchInspection(),
        _repository.fetchDefectCatalog(),
      ]);
      final snapshot = results[0] as InspectionSnapshot;
      _car = snapshot.car;
      _confirmed = snapshot.panels;
      _offline = snapshot.offline;
      _defectCatalog = results[1] as List<DefectDef>;
      _defectsByPanel = _indexDefects(_defectCatalog, _confirmed);
      _recompute();
      // долги прошлого раза — на сервер, если сеть есть
      if (!_offline) unawaited(_outbox?.flush());
    } catch (e) {
      _loadError = apiErrorText(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  static Map<String, List<String>> _indexDefects(
    List<DefectDef> catalog,
    List<InspectionPanel> panels,
  ) {
    // Бекенд без привязок (поле panels не пришло) — весь каталог на всё, как раньше.
    final unscoped = catalog.every((d) => d.panelCodes.isEmpty);
    return {
      for (final p in panels)
        p.id: [
          for (final d in catalog)
            if (unscoped || d.panelCodes.contains(p.id)) d.label,
        ],
    };
  }

  InspectionPanel panelById(String id) => _panels.firstWhere((p) => p.id == id);

  int indexOf(String id) => _panels.indexWhere((p) => p.id == id);

  InspectionPanel? nextAfter(String id) {
    final i = indexOf(id);
    if (i == -1 || i + 1 >= _panels.length) return null;
    return _panels[i + 1];
  }

  void _replacePanel(InspectionPanel updated) {
    final i = _confirmed.indexWhere((p) => p.id == updated.id);
    if (i == -1) return;
    _confirmed = [..._confirmed]..[i] = updated;
    _recompute();
    notifyListeners();
  }

  /// Действие — в очередь, сразу на экран; Future закончится, когда
  /// очередь отработает (в тестах с моком — ответ уже получен). Экраны его
  /// не ждут: без сети это минуты. Без очереди (только просмотр) — прямой
  /// запрос, как раньше.
  Future<void> _queue(
    Future<void> Function(InspectionOutbox outbox) enqueue,
    Future<InspectionPanel> Function() direct,
  ) async {
    final outbox = _outbox;
    if (outbox == null) return _replacePanel(await direct());
    await enqueue(outbox);
    await outbox.flush();
  }

  Future<void> applyCondition(String panelId, PanelCondition condition) =>
      _queue(
        (o) => o.setCondition(panelId, condition),
        () => _repository.updateCondition(panelId, condition),
      );

  /// Нажатие по дефекту на экране. Желаемое состояние — от того, что видел
  /// пользователь, на сервер уходит явное «поставить/снять» (setDefect):
  /// повтор запроса не перевернёт дефект обратно.
  Future<void> toggleDefect(String panelId, String defectLabel) {
    final defect = _defectCatalog.firstWhere((d) => d.label == defectLabel);
    final on = !panelById(panelId).defects.contains(defectLabel);
    return _queue(
      (o) => o.setDefect(panelId, defect.id, defectLabel, on: on),
      () => _repository.setDefect(panelId, defect.id, on: on),
    );
  }

  Future<void> uploadPhoto(String panelId, String filePath) => _queue(
    (o) => o.addPhoto(panelId, filePath),
    () => _repository.uploadPhoto(panelId, filePath),
  );

  Future<void> uploadAudioNote(
    String panelId,
    String filePath,
    int durationSeconds,
  ) => _queue(
    (o) => o.setAudio(panelId, filePath, durationSeconds),
    () => _repository.uploadAudioNote(panelId, filePath, durationSeconds),
  );

  Future<void> deleteAudioNote(String panelId) => _queue(
    (o) => o.deleteAudio(panelId),
    () => _repository.deleteAudioNote(panelId),
  );

  /// Удалить снимок детали: серверный — по id, ещё не отправленный — из
  /// очереди.
  Future<void> deletePhoto(String panelId, PanelPhoto photo) => _queue(
    (o) => o.deletePhoto(panelId, photo),
    () => _repository.deletePhoto(photo.id),
  );
}
