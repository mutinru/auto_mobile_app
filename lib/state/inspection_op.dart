import 'dart:math';

import '../models/inspection_panel.dart';
import '../models/panel_condition.dart';
import '../models/panel_status.dart';

/// Действие осмотра в очереди ([InspectionOutbox]): исполнитель уже видит его
/// результат, сервер — ещё нет. Хранится в JSON на диске, поэтому
/// переживает перезапуск приложения.
sealed class InspectionOp {
  const InspectionOp({required this.id, required this.panelId});

  /// Номер действия в очереди — по нему очередь снимает отправленное.
  final int id;
  final String panelId;

  /// Файл действия в папке очереди (фото, запись) — удаляется вместе с ним.
  String? get file => null;

  Map<String, dynamic> toJson();

  static InspectionOp fromJson(Map<String, dynamic> j) {
    final id = j['id'] as int;
    final panel = j['panel'] as String;
    return switch (j['type'] as String) {
      'condition' => SetConditionOp(
        id: id,
        panelId: panel,
        condition: panelConditionFromApi(j['condition'] as String)!,
      ),
      'defect' => SetDefectOp(
        id: id,
        panelId: panel,
        defectId: j['defect_id'] as int,
        label: j['label'] as String,
        on: j['on'] as bool,
      ),
      'add_photo' => AddPhotoOp(
        id: id,
        panelId: panel,
        clientId: j['client_id'] as String,
        path: j['path'] as String,
      ),
      'delete_photo' => DeletePhotoOp(
        id: id,
        panelId: panel,
        photoId: j['photo_id'] as int?,
        clientId: j['client_id'] as String?,
      ),
      'set_audio' => SetAudioOp(
        id: id,
        panelId: panel,
        path: j['path'] as String,
        seconds: j['seconds'] as int,
      ),
      'delete_audio' => DeleteAudioOp(id: id, panelId: panel),
      final t => throw FormatException('Неизвестное действие осмотра: $t'),
    };
  }

  Map<String, dynamic> _base(String type) => {
    'id': id,
    'panel': panelId,
    'type': type,
  };
}

class SetConditionOp extends InspectionOp {
  const SetConditionOp({
    required super.id,
    required super.panelId,
    required this.condition,
  });

  final PanelCondition condition;

  @override
  Map<String, dynamic> toJson() => {
    ..._base('condition'),
    'condition': condition.apiValue,
  };
}

/// Поставить или снять дефект — явным состоянием (PUT/DELETE), как №6.
class SetDefectOp extends InspectionOp {
  const SetDefectOp({
    required super.id,
    required super.panelId,
    required this.defectId,
    required this.label,
    required this.on,
  });

  final int defectId;
  final String label;
  final bool on;

  @override
  Map<String, dynamic> toJson() => {
    ..._base('defect'),
    'defect_id': defectId,
    'label': label,
    'on': on,
  };
}

/// Загрузка снимка: [clientId] — ключ повтора на сервере (`client_id`).
class AddPhotoOp extends InspectionOp {
  const AddPhotoOp({
    required super.id,
    required super.panelId,
    required this.clientId,
    required this.path,
  });

  final String clientId;
  final String path;

  @override
  String get file => path;

  @override
  Map<String, dynamic> toJson() => {
    ..._base('add_photo'),
    'client_id': clientId,
    'path': path,
  };
}

/// Удаление снимка: серверный [photoId] или, если снимок ушёл из очереди
/// и id ещё не известен, его [clientId].
class DeletePhotoOp extends InspectionOp {
  const DeletePhotoOp({
    required super.id,
    required super.panelId,
    this.photoId,
    this.clientId,
  }) : assert(photoId != null || clientId != null);

  final int? photoId;
  final String? clientId;

  @override
  Map<String, dynamic> toJson() => {
    ..._base('delete_photo'),
    'photo_id': ?photoId,
    'client_id': ?clientId,
  };
}

class SetAudioOp extends InspectionOp {
  const SetAudioOp({
    required super.id,
    required super.panelId,
    required this.path,
    required this.seconds,
  });

  final String path;
  final int seconds;

  @override
  String get file => path;

  @override
  Map<String, dynamic> toJson() => {
    ..._base('set_audio'),
    'path': path,
    'seconds': seconds,
  };
}

class DeleteAudioOp extends InspectionOp {
  const DeleteAudioOp({required super.id, required super.panelId});

  @override
  Map<String, dynamic> toJson() => _base('delete_audio');
}

/// Детали, какими их видит исполнитель: подтверждённые сервером плюс
/// действия очереди поверх. Единственное место, где статус и `missing`
/// считаются на телефоне, — и только у деталей с неотправленными
/// действиями; ответ сервера потом их заменит. [confirmed] не меняется.
List<InspectionPanel> applyPending(
  List<InspectionPanel> confirmed,
  List<InspectionOp> pending,
) {
  if (pending.isEmpty) return confirmed;
  final touched = {for (final op in pending) op.panelId};
  final byId = {
    for (final p in confirmed) p.id: touched.contains(p.id) ? p.copy() : p,
  };
  for (final op in pending) {
    final panel = byId[op.panelId];
    if (panel != null) _apply(panel, op);
  }
  for (final id in touched) {
    final panel = byId[id];
    if (panel != null) _recomputeMissing(panel);
  }
  return [for (final p in confirmed) byId[p.id]!];
}

void _apply(InspectionPanel panel, InspectionOp op) {
  switch (op) {
    case SetConditionOp(:final condition):
      panel.applyCondition(condition);
    case SetDefectOp(:final label, :final on):
      panel.setDefect(label, on: on);
    case AddPhotoOp(:final clientId, :final path):
      panel.photos.add(PanelPhoto.pending(clientId: clientId, path: path));
      panel.photoCount = panel.photos.length;
    case DeletePhotoOp(:final photoId, :final clientId):
      panel.photos.removeWhere(
        (p) =>
            (photoId != null && p.id == photoId) ||
            (clientId != null && p.clientId == clientId),
      );
      panel.photoCount = panel.photos.length;
    case SetAudioOp(:final path, :final seconds):
      panel
        ..audioNoteUrl = path
        ..audioNoteSeconds = seconds;
    case DeleteAudioOp():
      panel
        ..audioNoteUrl = null
        ..audioNoteSeconds = null;
  }
}

/// Повтор `InspectionPanel::missing()` с бекенда.
void _recomputeMissing(InspectionPanel panel) {
  final c = panel.condition;
  if (c == null) {
    panel
      ..status = PanelStatus.none
      ..missing = {InspectionPanel.missingCondition};
    return;
  }
  panel.missing = {
    if (c.requiresPhoto && panel.photos.isEmpty) InspectionPanel.missingPhoto,
    if (c.requiresDefect && panel.defects.isEmpty)
      InspectionPanel.missingDefect,
  };
}

final _random = Random.secure();

/// uuid v4 — ключ повтора загрузки фото.
String newClientId() {
  final b = List<int>.generate(16, (_) => _random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String hex(int from, int to) => [
    for (final x in b.sublist(from, to)) x.toRadixString(16).padLeft(2, '0'),
  ].join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
