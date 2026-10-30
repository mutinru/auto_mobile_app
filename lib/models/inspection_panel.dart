import '../config/api_config.dart';
import 'panel_condition.dart';
import 'panel_status.dart';

/// Пункт осмотра: деталь кузова на схеме или пункт вне её
/// (двигатель, пороги, окна, документы) — см. [isExtra].
///
/// Поля зеркалят InspectionPanelResource на бекенде
/// (app/Http/Resources/InspectionPanelResource.php):
/// id, name, zone, kind, status, condition, defects, photoCount, audio*.
class InspectionPanel {
  InspectionPanel({
    required this.id,
    required this.name,
    required this.zone,
    this.kind = 'body',
    required this.status,
    this.condition,
    Set<String>? defects,
    this.photoCount = 0,
    List<String>? photoUrls,
    this.audioNoteSeconds,
    this.audioNoteUrl,
  })  : defects = defects ?? <String>{},
        photoUrls = photoUrls ?? <String>[];

  final String id;
  final String name;

  /// Зона для группировки в списке (Перед / Двери / Верх / Зад / Дополнительно).
  final String zone;

  /// body — деталь на схеме кузова, extra — кнопка в боковой колонке схемы.
  final String kind;

  bool get isExtra => kind == 'extra';

  PanelStatus status;
  PanelCondition? condition;
  final Set<String> defects;
  int photoCount;

  /// Абсолютные ссылки на снимки детали.
  final List<String> photoUrls;
  int? audioNoteSeconds;

  /// Абсолютная подписанная ссылка на запись: открывается без токена,
  /// но живёт около часа — после этого осмотр надо перезагрузить.
  String? audioNoteUrl;

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
      kind: json['kind'] as String? ?? 'body',
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
      audioNoteUrl: audioNote == null ? null : _absolute(audioNote['url'] as String),
    );
  }
}


/// Бекенд отдаёт /storage/... — дописываем хост.
String _absolute(String url) =>
    url.startsWith('http') ? url : '${ApiConfig.origin}$url';
