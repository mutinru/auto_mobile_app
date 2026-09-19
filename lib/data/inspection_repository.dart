import '../models/car.dart';
import '../models/defect_def.dart';
import '../models/inspection_panel.dart';
import '../models/panel_condition.dart';

typedef InspectionSnapshot = ({Car car, List<InspectionPanel> panels});

/// Источник данных осмотра. Две реализации:
/// [MockInspectionRepository] — для UI-разработки без бекенда,
/// [ApiInspectionRepository] — Laravel API поверх http.
///
/// Мутации (updateCondition/toggleDefect) возвращают обновлённую
/// [InspectionPanel] целиком — InspectionStore просто подменяет её в
/// списке, не дублируя на клиенте логику вычисления статуса.
abstract class InspectionRepository {
  Future<InspectionSnapshot> fetchInspection();
  Future<List<DefectDef>> fetchDefectCatalog();
  Future<InspectionPanel> updateCondition(String panelId, PanelCondition condition);
  Future<InspectionPanel> toggleDefect(String panelId, int defectId);

  /// Загрузить снимок детали (multipart). Возвращает обновлённую деталь.
  Future<InspectionPanel> uploadPhoto(String panelId, String filePath);
}
