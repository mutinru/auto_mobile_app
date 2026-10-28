import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Статус детали кузова на схеме. Совпадает с классами
/// .panel.none/.progress/.done/.defect в HTML-макете.
///
/// На бекенде будет отдельным полем ответа API (см. PanelCondition —
/// status выводится из condition, не хранится отдельно).
enum PanelStatus { none, inProgress, done, defect }

extension PanelStatusX on PanelStatus {
  Color color(AppColors c) => switch (this) {
        PanelStatus.none => c.statusNone,
        PanelStatus.inProgress => c.statusProgress,
        PanelStatus.done => c.statusDone,
        PanelStatus.defect => c.statusDefect,
      };

  String get label => switch (this) {
        PanelStatus.none => 'Не начато',
        PanelStatus.inProgress => 'В работе',
        PanelStatus.done => 'Готово',
        PanelStatus.defect => 'Дефект',
      };
}

/// Разбор значения поля `status` из ответа Laravel API
/// (App\Enums\PanelStatus, snake_case-строки).
PanelStatus panelStatusFromApi(String value) => switch (value) {
      'in_progress' => PanelStatus.inProgress,
      'done' => PanelStatus.done,
      'defect' => PanelStatus.defect,
      _ => PanelStatus.none,
    };
