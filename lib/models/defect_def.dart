/// Запись каталога дефектов (GET /api/defects на бекенде).
/// id нужен только для вызова toggleDefect на реальном API — в UI
/// (chips на экране детали) используется label, он уникален в каталоге.
class DefectDef {
  const DefectDef({
    required this.id,
    required this.label,
    this.panelCodes = const {},
  });

  final int id;
  final String label;

  /// Коды пунктов осмотра, на которых дефект можно отметить
  /// (body_panel_type_defect на бекенде).
  final Set<String> panelCodes;

  factory DefectDef.fromJson(Map<String, dynamic> json) => DefectDef(
        id: json['id'] as int,
        label: json['label'] as String,
        panelCodes: {
          for (final c in (json['panels'] as List? ?? const [])) c as String,
        },
      );
}
