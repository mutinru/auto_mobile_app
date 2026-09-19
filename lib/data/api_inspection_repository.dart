import '../models/car.dart';
import '../models/defect_def.dart';
import '../models/inspection_panel.dart';
import '../models/panel_condition.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'inspection_repository.dart';

/// Реализация поверх Laravel API (routes/api.php).
///
/// TODO(current-inspection): пока нет эндпоинта "мой текущий осмотр",
/// id=1 — это демо-осмотр из DemoInspectionSeeder. Когда появится выбор
/// автомобиля/осмотра в приложении, id должен приходить оттуда.
class ApiInspectionRepository implements InspectionRepository {
  ApiInspectionRepository(this._client, {this.inspectionId = 1});

  final ApiClient _client;
  final int inspectionId;

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
    final json = await _client.get('/defects');
    return (json['data'] as List)
        .map((d) => DefectDef(id: d['id'] as int, label: d['label'] as String))
        .toList();
  }

  @override
  Future<InspectionPanel> updateCondition(String panelId, PanelCondition condition) async {
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
    // multipart идёт мимо ApiClient — тот умеет только JSON
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/inspections/$inspectionId/panels/$panelId/photos'),
    )
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer ${_client.token}'
      ..files.add(await http.MultipartFile.fromPath('photo', filePath));

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw ApiException(streamed.statusCode, body);
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    return InspectionPanel.fromJson(json['data'] as Map<String, dynamic>);
  }
}
