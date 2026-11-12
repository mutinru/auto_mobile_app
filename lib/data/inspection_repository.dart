import '../models/car.dart';
import '../models/defect_def.dart';
import '../models/inspection_panel.dart';
import '../models/panel_condition.dart';

/// [offline] — сети нет, осмотр взят из копии на телефоне
/// (`InspectionCache`): фото с сервера в ней не откроются.
typedef InspectionSnapshot = ({
  Car car,
  List<InspectionPanel> panels,
  bool offline,
});

/// Источник данных осмотра. Две реализации:
/// [MockInspectionRepository] — для UI-разработки без бекенда,
/// [ApiInspectionRepository] — Laravel API поверх http.
///
/// Мутации (updateCondition/setDefect) возвращают обновлённую
/// [InspectionPanel] целиком — InspectionStore просто подменяет её в
/// списке, не дублируя на клиенте логику вычисления статуса.
abstract class InspectionRepository {
  Future<InspectionSnapshot> fetchInspection();
  Future<List<DefectDef>> fetchDefectCatalog();
  Future<InspectionPanel> updateCondition(
    String panelId,
    PanelCondition condition,
  );

  /// Поставить ([on]) или снять дефект — явным состоянием, а не
  /// переключателем: повтор после обрыва связи не снимет только что
  /// поставленный дефект.
  Future<InspectionPanel> setDefect(
    String panelId,
    int defectId, {
    required bool on,
  });

  /// Загрузить снимок детали (multipart). Возвращает обновлённую деталь.
  /// [clientId] — ключ повтора: сервер не создаст второе фото с тем же.
  Future<InspectionPanel> uploadPhoto(
    String panelId,
    String filePath, {
    String? clientId,
    PhotoSource source = PhotoSource.camera,
    String? takenAt,
  });

  /// Загрузить или заменить голосовую заметку детали (одна на деталь).
  /// Длительность считает клиент — сервер аудио не разбирает.
  Future<InspectionPanel> uploadAudioNote(
    String panelId,
    String filePath,
    int durationSeconds,
  );

  Future<InspectionPanel> deleteAudioNote(String panelId);

  /// Удалить снимок детали. Возвращает обновлённую деталь (с пересчитанным
  /// missing). Сервер пускает только исполнителя идущего осмотра.
  Future<InspectionPanel> deletePhoto(int photoId);
}
