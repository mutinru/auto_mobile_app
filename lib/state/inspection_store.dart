import 'package:flutter/foundation.dart';

import '../data/inspection_repository.dart';
import '../models/car.dart';
import '../models/defect_def.dart';
import '../models/inspection_panel.dart';
import '../models/panel_condition.dart';
import '../models/panel_status.dart';
import '../widgets/api_error.dart';

/// Единственный источник правды для экрана осмотра в рамках сессии.
///
/// applyCondition/toggleDefect зовут [InspectionRepository] на запись и
/// подменяют панель в списке результатом с сервера (или мока) — клиент
/// не дублирует логику статуса/дефектов, только показывает то, что
/// вернул источник данных.
class InspectionStore extends ChangeNotifier {
  InspectionStore(this._repository, {this.readOnly = false});

  final InspectionRepository _repository;

  /// Осмотр только для просмотра: заказчик подбора смотрит кандидата, сервер
  /// запись ему не разрешит (403). Экраны гасят все мутации.
  final bool readOnly;

  Car? _car;
  List<InspectionPanel> _panels = const [];
  List<DefectDef> _defectCatalog = const [];

  /// код пункта -> метки доступных дефектов в порядке каталога; строится
  /// один раз при [load], экран детали читает его на каждой перерисовке.
  Map<String, List<String>> _defectsByPanel = const {};
  bool _loading = false;
  String? _loadError;

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
      final results = await Future.wait([
        _repository.fetchInspection(),
        _repository.fetchDefectCatalog(),
      ]);
      final snapshot = results[0] as InspectionSnapshot;
      _car = snapshot.car;
      _panels = snapshot.panels;
      _defectCatalog = results[1] as List<DefectDef>;
      _defectsByPanel = _indexDefects(_defectCatalog, _panels);
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
    final i = indexOf(updated.id);
    if (i == -1) return;
    _panels = [..._panels]..[i] = updated;
    notifyListeners();
  }

  Future<void> applyCondition(String panelId, PanelCondition condition) async {
    final updated = await _repository.updateCondition(panelId, condition);
    _replacePanel(updated);
  }

  Future<void> toggleDefect(String panelId, String defectLabel) async {
    final defect = _defectCatalog.firstWhere((d) => d.label == defectLabel);
    final updated = await _repository.toggleDefect(panelId, defect.id);
    _replacePanel(updated);
  }

  Future<void> uploadPhoto(String panelId, String filePath) async {
    final updated = await _repository.uploadPhoto(panelId, filePath);
    _replacePanel(updated);
  }

  Future<void> uploadAudioNote(
    String panelId,
    String filePath,
    int durationSeconds,
  ) async {
    final updated = await _repository.uploadAudioNote(
      panelId,
      filePath,
      durationSeconds,
    );
    _replacePanel(updated);
  }

  Future<void> deleteAudioNote(String panelId) async {
    final updated = await _repository.deleteAudioNote(panelId);
    _replacePanel(updated);
  }

  Future<void> deletePhoto(int photoId) async {
    final updated = await _repository.deletePhoto(photoId);
    _replacePanel(updated);
  }
}
