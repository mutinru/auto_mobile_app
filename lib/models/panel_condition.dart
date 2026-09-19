import 'panel_status.dart';

/// Оценка состояния детали A/B/C/D (секция "Состояние" на экране детали).
enum PanelCondition { excellent, good, satisfactory, needsRepair }

extension PanelConditionX on PanelCondition {
  String get grade => switch (this) {
        PanelCondition.excellent => 'A',
        PanelCondition.good => 'B',
        PanelCondition.satisfactory => 'C',
        PanelCondition.needsRepair => 'D',
      };

  String get label => switch (this) {
        PanelCondition.excellent => 'Отличное',
        PanelCondition.good => 'Хорошее',
        PanelCondition.satisfactory => 'Удовлетв.',
        PanelCondition.needsRepair => 'К ремонту',
      };

  /// Статус детали на схеме, производный от оценки состояния —
  /// повторяет логику мокапа (cond-dot цвет = st-статус).
  PanelStatus get impliedStatus => switch (this) {
        PanelCondition.excellent => PanelStatus.done,
        PanelCondition.good => PanelStatus.done,
        PanelCondition.satisfactory => PanelStatus.inProgress,
        PanelCondition.needsRepair => PanelStatus.defect,
      };

  /// Значение, которое ждёт Laravel API (App\Enums\PanelCondition).
  String get apiValue => switch (this) {
        PanelCondition.excellent => 'excellent',
        PanelCondition.good => 'good',
        PanelCondition.satisfactory => 'satisfactory',
        PanelCondition.needsRepair => 'needs_repair',
      };
}

PanelCondition? panelConditionFromApi(String? value) => switch (value) {
      'excellent' => PanelCondition.excellent,
      'good' => PanelCondition.good,
      'satisfactory' => PanelCondition.satisfactory,
      'needs_repair' => PanelCondition.needsRepair,
      _ => null,
    };
