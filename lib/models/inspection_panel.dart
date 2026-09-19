import '../config/api_config.dart';
import 'panel_condition.dart';
import 'panel_status.dart';

/// Деталь кузова в рамках одного осмотра.
///
/// Поля зеркалят InspectionPanelResource на бекенде
/// (app/Http/Resources/InspectionPanelResource.php):
/// id, name, zone, status, condition, defects, photoCount, audio*.
class InspectionPanel {
  InspectionPanel({
    required this.id,
    required this.name,
    required this.zone,
    required this.status,
    this.condition,
    Set<String>? defects,
    this.photoCount = 0,
    List<String>? photoUrls,
    this.audioNoteSeconds,
  })  : defects = defects ?? <String>{},
        photoUrls = photoUrls ?? <String>[];

  final String id;
  final String name;

  /// Зона кузова для группировки в списке (Перед / Двери и крылья / Верх / Зад).
  final String zone;

  PanelStatus status;
  PanelCondition? condition;
  final Set<String> defects;
  int photoCount;

  /// Абсолютные ссылки на снимки детали.
  final List<String> photoUrls;
  int? audioNoteSeconds;

  void applyCondition(PanelCondition condition) {
    this.condition = condition;
    status = condition.impliedStatus;
  }

  void toggleDefect(String defect) {
    if (!defects.remove(defect)) {
      defects.add(defect);
    }
  }

  factory InspectionPanel.fromJson(Map<String, dynamic> json) {
    final audioNote = json['audio_note'] as Map<String, dynamic>?;
    return InspectionPanel(
      id: json['id'] as String,
      name: json['name'] as String,
      zone: json['zone'] as String,
      status: panelStatusFromApi(json['status'] as String),
      condition: panelConditionFromApi(json['condition'] as String?),
      defects: {
        for (final d in (json['defects'] as List)) (d as Map<String, dynamic>)['label'] as String,
      },
      photoCount: json['photo_count'] as int,
      photoUrls: [
        for (final p in (json['photos'] as List? ?? const []))
          _absolute((p as Map<String, dynamic>)['url'] as String),
      ],
      audioNoteSeconds: audioNote?['duration_seconds'] as int?,
    );
  }
}


/// Бекенд отдаёт /storage/... — дописываем хост.
String _absolute(String url) =>
    url.startsWith('http') ? url : '${ApiConfig.origin}$url';
