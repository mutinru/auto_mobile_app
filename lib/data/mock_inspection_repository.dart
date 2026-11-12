import '../models/car.dart';
import '../models/defect_def.dart';
import '../models/inspection_panel.dart';

import '../models/panel_condition.dart';
import '../models/panel_status.dart';
import 'inspection_repository.dart';

const _body = {
  'front_bumper',
  'front_left_fender',
  'front_right_fender',
  'hood',
  'front_left_door',
  'front_right_door',
  'rear_left_door',
  'rear_right_door',
  'roof',
  'rear_left_fender',
  'rear_right_fender',
  'trunk',
  'rear_bumper',
};

/// Тот же каталог и привязки, что в DefectSeeder на бекенде.
const _mockDefects = [
  DefectDef(id: 1, label: 'Царапины', panelCodes: _body),
  DefectDef(id: 2, label: 'Скол ЛКП', panelCodes: _body),
  DefectDef(id: 3, label: 'Вмятина', panelCodes: {..._body, 'sills'}),
  DefectDef(id: 4, label: 'Коррозия', panelCodes: {..._body, 'sills'}),
  DefectDef(id: 5, label: 'Перекрашено', panelCodes: {..._body, 'sills'}),
  DefectDef(id: 6, label: 'Зазоры', panelCodes: _body),
  DefectDef(id: 7, label: 'Сквозная гниль', panelCodes: {'sills'}),
  DefectDef(id: 8, label: 'Следы сварки', panelCodes: {'sills'}),
  DefectDef(id: 9, label: 'Течь масла', panelCodes: {'engine'}),
  DefectDef(id: 10, label: 'Течь ОЖ', panelCodes: {'engine'}),
  DefectDef(id: 11, label: 'Посторонний стук', panelCodes: {'engine'}),
  DefectDef(id: 12, label: 'Нестабильные обороты', panelCodes: {'engine'}),
  DefectDef(id: 13, label: 'Дым из выхлопа', panelCodes: {'engine'}),
  DefectDef(id: 14, label: 'Ошибки ЭБУ', panelCodes: {'engine'}),
  DefectDef(id: 15, label: 'Скол', panelCodes: {'windows'}),
  DefectDef(id: 16, label: 'Трещина', panelCodes: {'windows'}),
  DefectDef(id: 17, label: 'Не заводское стекло', panelCodes: {'windows'}),
  DefectDef(
    id: 18,
    label: 'Неисправен стеклоподъёмник',
    panelCodes: {'windows'},
  ),
  DefectDef(id: 19, label: 'VIN не совпадает', panelCodes: {'documents'}),
  DefectDef(id: 20, label: 'Дубликат ПТС', panelCodes: {'documents'}),
  DefectDef(id: 21, label: 'Залог или ограничения', panelCodes: {'documents'}),
  DefectDef(id: 22, label: 'Много владельцев', panelCodes: {'documents'}),
  DefectDef(id: 23, label: 'Пробег не сходится', panelCodes: {'documents'}),
];

/// Повторяет ровно тот датасет, что зашит в HTML-макете
/// (design/app_auto_podbor.html) и в DemoInspectionSeeder на бекенде:
/// 8 done, 3 in-progress, 1 defect, 5 none — итого 12/17 оценено
/// (точки боковых кнопок: двигатель и окна готовы, пороги в работе).
///
/// Хранит панели в памяти (не пересоздаёт на каждый fetch), чтобы
/// поведение мутаций (updateCondition/setDefect) было таким же,
/// как у ApiInspectionRepository — стору без разницы, с каким источником
/// он работает.
class MockInspectionRepository implements InspectionRepository {
  MockInspectionRepository() : _blank = false;

  /// Только что начатый осмотр: те же пункты, ни одной оценки.
  MockInspectionRepository.blank() : _blank = true;

  final bool _blank;

  List<InspectionPanel>? _panels;

  /// id следующего снимка — как автоинкремент photos на бекенде.
  int _nextPhotoId = 1;

  List<InspectionPanel> get _loadedPanels => _panels ??= [
    for (final p in _blank ? _buildPanels().map(_unrated) : _buildPanels())
      _withMissing(p),
  ];

  /// Мок сам считает поле missing — повтор InspectionPanel::missing() с
  /// бекенда: «Удовлетв.» — фото, «К ремонту» — фото и дефект.
  static InspectionPanel _withMissing(InspectionPanel p) {
    final c = p.condition;
    p.missing = {
      if (c == null) InspectionPanel.missingCondition,
      if ((c == PanelCondition.satisfactory ||
              c == PanelCondition.needsRepair) &&
          p.photoCount == 0)
        InspectionPanel.missingPhoto,
      if (c == PanelCondition.needsRepair && p.defects.isEmpty)
        InspectionPanel.missingDefect,
    };
    return p;
  }

  static InspectionPanel _unrated(InspectionPanel p) => InspectionPanel(
    id: p.id,
    name: p.name,
    zone: p.zone,
    kind: p.kind,
    status: PanelStatus.none,
  );

  @override
  Future<InspectionSnapshot> fetchInspection() async {
    const car = Car(
      brand: 'Toyota',
      model: 'Camry',
      year: 2019,
      vinMasked: '··· KX24P',
      mileageKm: 127450,
      // продавец указал меньше — в отчёте плашка расхождения
      customerMileageKm: 120000,
      mileageMismatch: true,
    );
    return (car: car, panels: _loadedPanels, offline: false);
  }

  @override
  Future<List<DefectDef>> fetchDefectCatalog() async => _mockDefects;

  @override
  Future<InspectionPanel> updateCondition(
    String panelId,
    PanelCondition condition,
  ) async {
    final panel = _loadedPanels.firstWhere((p) => p.id == panelId);
    panel.applyCondition(condition);
    return _withMissing(panel);
  }

  @override
  Future<InspectionPanel> setDefect(
    String panelId,
    int defectId, {
    required bool on,
  }) async {
    final panel = _loadedPanels.firstWhere((p) => p.id == panelId);
    final label = _mockDefects.firstWhere((d) => d.id == defectId).label;
    panel.setDefect(label, on: on);
    return _withMissing(panel);
  }

  List<InspectionPanel> _buildPanels() => [
    InspectionPanel(
      id: 'front_bumper',
      name: 'Передний бампер',
      zone: 'Перед',
      condition: PanelCondition.satisfactory,
      status: PanelStatus.inProgress,
    ),
    InspectionPanel(
      id: 'front_left_fender',
      name: 'Переднее левое крыло',
      zone: 'Перед',
      condition: PanelCondition.good,
      status: PanelStatus.done,
    ),
    InspectionPanel(
      id: 'front_right_fender',
      name: 'Переднее правое крыло',
      zone: 'Перед',
      condition: PanelCondition.needsRepair,
      status: PanelStatus.defect,
    ),
    InspectionPanel(
      id: 'hood',
      name: 'Капот',
      zone: 'Перед',
      condition: PanelCondition.good,
      status: PanelStatus.done,
    ),
    InspectionPanel(
      id: 'front_left_door',
      name: 'Передняя левая дверь',
      zone: 'Двери',
      condition: PanelCondition.good,
      status: PanelStatus.done,
    ),
    InspectionPanel(
      id: 'front_right_door',
      name: 'Передняя правая дверь',
      zone: 'Двери',
      condition: PanelCondition.satisfactory,
      status: PanelStatus.inProgress,
    ),
    InspectionPanel(
      id: 'rear_left_door',
      name: 'Задняя левая дверь',
      zone: 'Двери',
      condition: PanelCondition.good,
      status: PanelStatus.done,
    ),
    InspectionPanel(
      id: 'rear_right_door',
      name: 'Задняя правая дверь',
      zone: 'Двери',
      condition: PanelCondition.good,
      status: PanelStatus.done,
    ),
    InspectionPanel(
      id: 'roof',
      name: 'Крыша',
      zone: 'Верх',
      condition: PanelCondition.good,
      status: PanelStatus.done,
    ),
    InspectionPanel(
      id: 'rear_left_fender',
      name: 'Заднее левое крыло',
      zone: 'Зад',
      status: PanelStatus.none,
    ),
    InspectionPanel(
      id: 'rear_right_fender',
      name: 'Заднее правое крыло',
      zone: 'Зад',
      status: PanelStatus.none,
    ),
    InspectionPanel(
      id: 'trunk',
      name: 'Крышка багажника',
      zone: 'Зад',
      status: PanelStatus.none,
    ),
    InspectionPanel(
      id: 'rear_bumper',
      name: 'Задний бампер',
      zone: 'Зад',
      status: PanelStatus.none,
    ),
    InspectionPanel(
      id: 'engine',
      name: 'Двигатель',
      zone: 'Дополнительно',
      kind: 'extra',
      condition: PanelCondition.good,
      status: PanelStatus.done,
    ),
    InspectionPanel(
      id: 'sills',
      name: 'Пороги',
      zone: 'Дополнительно',
      kind: 'extra',
      condition: PanelCondition.satisfactory,
      status: PanelStatus.inProgress,
    ),
    InspectionPanel(
      id: 'windows',
      name: 'Окна',
      zone: 'Дополнительно',
      kind: 'extra',
      condition: PanelCondition.excellent,
      status: PanelStatus.done,
    ),
    InspectionPanel(
      id: 'documents',
      name: 'Документы',
      zone: 'Дополнительно',
      kind: 'extra',
      status: PanelStatus.none,
    ),
  ];

  @override
  Future<InspectionPanel> uploadPhoto(
    String panelId,
    String filePath, {
    String? clientId,
  }) async {
    final panel = _loadedPanels.firstWhere((p) => p.id == panelId);
    // повтор с тем же ключом — как сервер: второе фото не создаётся
    if (clientId != null && panel.photos.any((p) => p.clientId == clientId)) {
      return _withMissing(panel);
    }
    final id = _nextPhotoId++;
    panel.photos.add(
      PanelPhoto(
        id: id,
        url: 'http://localhost/mock/photo/$id.jpg',
        thumbUrl: 'http://localhost/mock/photo/$id.thumb.jpg',
        clientId: clientId,
      ),
    );
    panel.photoCount++;
    return _withMissing(panel);
  }

  @override
  Future<InspectionPanel> deletePhoto(int photoId) async {
    final panel = _loadedPanels.firstWhere(
      (p) => p.photos.any((ph) => ph.id == photoId),
    );
    panel.photos.removeWhere((ph) => ph.id == photoId);
    panel.photoCount--;
    return _withMissing(panel);
  }

  @override
  Future<InspectionPanel> uploadAudioNote(
    String panelId,
    String filePath,
    int durationSeconds,
  ) async {
    final panel = _loadedPanels.firstWhere((p) => p.id == panelId);
    panel
      ..audioNoteSeconds = durationSeconds
      ..audioNoteUrl = 'http://localhost/mock/audio/$panelId.m4a';
    return panel;
  }

  @override
  Future<InspectionPanel> deleteAudioNote(String panelId) async {
    final panel = _loadedPanels.firstWhere((p) => p.id == panelId);
    panel
      ..audioNoteSeconds = null
      ..audioNoteUrl = null;
    return panel;
  }
}
