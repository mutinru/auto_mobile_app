import '../models/car.dart';
import '../models/defect_def.dart';
import '../models/inspection_panel.dart';
import '../models/panel_condition.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_client.dart';
import 'inspection_repository.dart';

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

  @override
  Future<InspectionSnapshot> fetchInspection() async {
    final json = await _client.get('/inspections/$inspectionId');
    final data = json['data'] as Map<String, dynamic>;
    final car = Car.fromJson(data['car'] as Map<String, dynamic>);
    final panels = (data['panels'] as List)
        .map((p) => InspectionPanel.fromJson(p as Map<String, dynamic>))
        .toList();
    return (car: car, panels: panels);
  }

  @override
  Future<List<DefectDef>> fetchDefectCatalog() async {
    // ETag шлём только при наличии копии — иначе 304 нечем было бы ответить
    final fresh = await _client.getIfChanged(
      '/defects',
      etag: _catalog == null ? null : _catalogEtag,
    );
    if (fresh != null) {
      _catalog = [
        for (final d in fresh.json['data'] as List)
          DefectDef.fromJson(d as Map<String, dynamic>),
      ];
      _catalogEtag = fresh.etag;
    }
    return _catalog!;
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
    return InspectionPanel.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<InspectionPanel> toggleDefect(String panelId, int defectId) async {
    final json = await _client.post(
      '/inspections/$inspectionId/panels/$panelId/defects/$defectId',
    );
    return InspectionPanel.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<InspectionPanel> uploadPhoto(String panelId, String filePath) async {
    return _multipart(
      '/inspections/$inspectionId/panels/$panelId/photos',
      await http.MultipartFile.fromPath('photo', filePath),
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
    return InspectionPanel.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// multipart идёт мимо ApiClient — тот умеет только JSON; ошибки всё равно
  /// через [ApiClient.failure], чтобы 401 стёр сессию.
  Future<InspectionPanel> _multipart(
    String path,
    http.MultipartFile file, {
    Map<String, String> fields = const {},
  }) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}$path'))
          ..headers['Accept'] = 'application/json'
          ..headers['Authorization'] = 'Bearer ${_client.token}'
          ..fields.addAll(fields)
          ..files.add(file);

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw _client.failure(streamed.statusCode, body);
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    return InspectionPanel.fromJson(json['data'] as Map<String, dynamic>);
  }
}
