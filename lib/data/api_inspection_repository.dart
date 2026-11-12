import '../models/car.dart';
import '../widgets/api_error.dart';
import '../models/defect_def.dart';
import '../models/inspection_panel.dart';
import '../models/panel_condition.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'inspection_cache.dart';
import 'inspection_repository.dart';
import 'photo_upload.dart';

/// Реализация поверх Laravel API (routes/api.php).
///
/// id осмотра всегда приходит от экрана (кандидат заказа). Значения по
/// умолчанию нет намеренно: забытый id молча открыл бы чужой осмотр.
class ApiInspectionRepository implements InspectionRepository {
  ApiInspectionRepository(this._client, {required this.inspectionId});

  final ApiClient _client;
  final int inspectionId;

  /// Каталог дефектов общий для всех осмотров и меняется только сидером на
  /// бекенде — держим одну копию на процесс и переспрашиваем по ETag (304).
  static List<DefectDef>? _catalog;
  static String? _catalogEtag;

  /// Без сети — копия с телефона ([InspectionCache]), если есть: осмотр
  /// в паркинге не встаёт, а действия уйдут очередью.
  @override
  Future<InspectionSnapshot> fetchInspection() async {
    Map<String, dynamic> data;
    var offline = false;
    try {
      final json = await _client.get('/inspections/$inspectionId');
      data = json['data'] as Map<String, dynamic>;
      await InspectionCache.saveInspection(inspectionId, data);
    } catch (e) {
      final cached = isNetworkError(e)
          ? await InspectionCache.loadInspection(inspectionId)
          : null;
      if (cached == null) rethrow;
      data = cached;
      offline = true;
    }
    final car = Car.fromJson(data['car'] as Map<String, dynamic>);
    final panels = (data['panels'] as List)
        .map((p) => InspectionPanel.fromJson(p as Map<String, dynamic>))
        .toList();
    return (car: car, panels: panels, offline: offline);
  }

  @override
  Future<List<DefectDef>> fetchDefectCatalog() async {
    if (_catalog == null) {
      // копия с диска — и без сети, и как основа для 304
      final saved = await InspectionCache.loadDefects();
      if (saved != null) {
        _catalog = _parseDefects(saved.data);
        _catalogEtag = saved.etag;
      }
    }
    try {
      final fresh = await _client.getIfChanged('/defects', etag: _catalogEtag);
      if (fresh != null) {
        final data = fresh.json['data'] as List;
        _catalog = _parseDefects(data);
        _catalogEtag = fresh.etag;
        await InspectionCache.saveDefects(data, fresh.etag);
      }
    } catch (e) {
      if (_catalog == null || !isNetworkError(e)) rethrow;
    }
    return _catalog!;
  }

  static List<DefectDef> _parseDefects(List<dynamic> data) => [
    for (final d in data) DefectDef.fromJson(d as Map<String, dynamic>),
  ];

  /// Деталь из ответа мутации — в копию осмотра, чтобы та не отставала.
  Future<InspectionPanel> _panel(Map<String, dynamic> json) async {
    final data = json['data'] as Map<String, dynamic>;
    await InspectionCache.savePanel(inspectionId, data);
    return InspectionPanel.fromJson(data);
  }

  @override
  Future<InspectionPanel> updateCondition(
    String panelId,
    PanelCondition condition,
  ) async {
    final json = await _client.patch(
      '/inspections/$inspectionId/panels/$panelId',
      {'condition': condition.apiValue},
    );
    return _panel(json);
  }

  @override
  Future<InspectionPanel> setDefect(
    String panelId,
    int defectId, {
    required bool on,
  }) async {
    // PUT ставит, DELETE снимает — повтор того же запроса ничего не меняет
    final path = '/inspections/$inspectionId/panels/$panelId/defects/$defectId';
    final json = on ? await _client.put(path) : await _client.delete(path);
    return _panel(json);
  }

  @override
  Future<InspectionPanel> uploadPhoto(
    String panelId,
    String filePath, {
    String? clientId,
  }) {
    return withUploadCopy(
      filePath,
      (upload) async => _multipart(
        '/inspections/$inspectionId/panels/$panelId/photos',
        await http.MultipartFile.fromPath('photo', upload),
        fields: {'client_id': ?clientId},
      ),
    );
  }

  @override
  Future<InspectionPanel> uploadAudioNote(
    String panelId,
    String filePath,
    int durationSeconds,
  ) async {
    return _multipart(
      '/inspections/$inspectionId/panels/$panelId/audio-note',
      await http.MultipartFile.fromPath('audio', filePath),
      fields: {'duration_seconds': '$durationSeconds'},
    );
  }

  @override
  Future<InspectionPanel> deleteAudioNote(String panelId) async {
    final json = await _client.delete(
      '/inspections/$inspectionId/panels/$panelId/audio-note',
    );
    return _panel(json);
  }

  @override
  Future<InspectionPanel> deletePhoto(int photoId) async {
    final json = await _client.delete('/photos/$photoId');
    return _panel(json);
  }

  Future<InspectionPanel> _multipart(
    String path,
    http.MultipartFile file, {
    Map<String, String> fields = const {},
  }) async {
    final json = await _client.multipart(path, fields: fields, files: [file]);
    return _panel(json);
  }
}
