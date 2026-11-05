import '../config/api_config.dart';
import 'panel_condition.dart';
import 'panel_status.dart';

/// Снимок детали: id — для удаления (DELETE /photos/{id}), url — абсолютная
/// подписанная ссылка, Bearer не нужен.
class PanelPhoto {
  const PanelPhoto({required this.id, required this.url});

  final int id;
  final String url;
}

/// Пункт осмотра: деталь кузова на схеме или пункт вне её
/// (двигатель, пороги, окна, документы) — см. [isExtra].
///
/// Поля зеркалят InspectionPanelResource на бекенде
/// (app/Http/Resources/InspectionPanelResource.php):
/// id, name, zone, kind, status, condition, defects, photoCount, missing, audio*.
class InspectionPanel {
  /// Сколько фото можно на одну деталь. Ручное зеркало
  /// `Photo::MAX_PER_PANEL` на бекенде (сверх него — 422): меняя одно, меняй
  /// другое (QA 2026-11-05 №16).
  static const maxPhotos = 5;

  InspectionPanel({
    required this.id,
    required this.name,
    required this.zone,
    this.kind = 'body',
    required this.status,
    this.condition,
    Set<String>? defects,
    this.photoCount = 0,
    List<PanelPhoto>? photos,
    this.audioNoteSeconds,
    this.audioNoteUrl,
    Set<String>? missing,
  }) : defects = defects ?? <String>{},
       photos = photos ?? <PanelPhoto>[],
       missing = missing ?? <String>{};

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

  /// Снимки детали в порядке загрузки.
  final List<PanelPhoto> photos;
  int? audioNoteSeconds;

  /// Абсолютная подписанная ссылка на запись: открывается без токена,
  /// но живёт около часа — после этого осмотр надо перезагрузить.
  String? audioNoteUrl;

  /// Чего не хватает для отчёта: [missingCondition], [missingPhoto],
  /// [missingDefect]. Правило считает бекенд (InspectionPanel::missing()),
  /// клиент только показывает; старый бекенд поле не шлёт — пусто.
  Set<String> missing;

  static const missingCondition = 'condition';
  static const missingPhoto = 'photo';
  static const missingDefect = 'defect';

  bool get needsPhoto => missing.contains(missingPhoto);
  bool get needsDefect => missing.contains(missingDefect);

  /// Оценена, но для отчёта не хватает фото или дефекта.
  bool get isIncomplete => condition != null && (needsPhoto || needsDefect);

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
        for (final d in (json['defects'] as List))
          (d as Map<String, dynamic>)['label'] as String,
      },
      photoCount: json['photo_count'] as int,
      photos: [
        for (final p in (json['photos'] as List? ?? const []))
          PanelPhoto(
            id: (p as Map<String, dynamic>)['id'] as int,
            url: _absolute(p['url'] as String),
          ),
      ],
      audioNoteSeconds: audioNote?['duration_seconds'] as int?,
      audioNoteUrl: audioNote == null
          ? null
          : _absolute(audioNote['url'] as String),
      missing: {
        for (final m in (json['missing'] as List? ?? const [])) m as String,
      },
    );
  }
}

/// Бекенд отдаёт относительную подписанную ссылку — дописываем хост.
String _absolute(String url) =>
    url.startsWith('http') ? url : '${ApiConfig.origin}$url';

/// [_absolute] для необязательной ссылки (фото таблички VIN и т. п.).
String? mediaUrl(String? url) => url == null ? null : _absolute(url);
