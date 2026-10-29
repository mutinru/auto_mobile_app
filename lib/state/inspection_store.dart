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
  bool _loading = false;
  String? _loadError;

  Car? get car => _car;

  /// Текст ошибки загрузки — без него экран остался бы на спиннере:
  /// гейт там ещё и на car == null.
  String? get loadError => _loadError;
  List<InspectionPanel> get panels => List.unmodifiable(_panels);
  List<String> get defectLabels => _defectCatalog.map((d) => d.label).toList();
  bool get isLoading => _loading;

  int get totalCount => _panels.length;
  int get evaluatedCount =>
      _panels.where((p) => p.status != PanelStatus.none).length;
  int get remainingCount => totalCount - evaluatedCount;

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
    } catch (e) {
      _loadError = apiErrorText(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  InspectionPanel panelById(String id) =>
      _panels.firstWhere((p) => p.id == id);

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
}
