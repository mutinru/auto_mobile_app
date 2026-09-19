import '../models/car.dart';
import '../models/defect_def.dart';
import '../models/inspection_panel.dart';

import '../models/panel_condition.dart';
import '../models/panel_status.dart';
import 'inspection_repository.dart';

const _mockDefects = [
  DefectDef(id: 1, label: 'Царапины'),
  DefectDef(id: 2, label: 'Скол ЛКП'),
  DefectDef(id: 3, label: 'Вмятина'),
  DefectDef(id: 4, label: 'Коррозия'),
  DefectDef(id: 5, label: 'Перекрашено'),
  DefectDef(id: 6, label: 'Зазоры'),
];

/// Повторяет ровно тот датасет, что зашит в HTML-макете
/// (design/app_auto_podbor.html) и в DemoInspectionSeeder на бекенде:
/// 6 done, 2 in-progress, 1 defect, 4 none — итого 9/13 оценено.
///
/// Хранит панели в памяти (не пересоздаёт на каждый fetch), чтобы
/// поведение мутаций (updateCondition/toggleDefect) было таким же,
/// как у ApiInspectionRepository — стору без разницы, с каким источником
/// он работает.
class MockInspectionRepository implements InspectionRepository {
  MockInspectionRepository();

  List<InspectionPanel>? _panels;

  List<InspectionPanel> get _loadedPanels => _panels ??= _buildPanels();

  @override
  Future<InspectionSnapshot> fetchInspection() async {
    const car = Car(
      brand: 'Toyota',
      model: 'Camry',
      year: 2019,
      vinMasked: '··· KX24P',
      mileageKm: 127450,
    );
    return (car: car, panels: _loadedPanels);
  }

  @override
  Future<List<DefectDef>> fetchDefectCatalog() async => _mockDefects;

  @override
  Future<InspectionPanel> updateCondition(String panelId, PanelCondition condition) async {
    final panel = _loadedPanels.firstWhere((p) => p.id == panelId);
    panel.applyCondition(condition);
    return panel;
  }

  @override
  Future<InspectionPanel> toggleDefect(String panelId, int defectId) async {
    final panel = _loadedPanels.firstWhere((p) => p.id == panelId);
    final label = _mockDefects.firstWhere((d) => d.id == defectId).label;
    panel.toggleDefect(label);
    return panel;
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
      ];

  @override
  Future<InspectionPanel> uploadPhoto(String panelId, String filePath) async {
    final panel = _loadedPanels.firstWhere((p) => p.id == panelId);
    panel.photoCount++;
    return panel;
  }
}
