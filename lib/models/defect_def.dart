/// Запись каталога дефектов (GET /api/defects на бекенде).
/// id нужен только для вызова toggleDefect на реальном API — в UI
/// (chips на экране детали) используется label.
class DefectDef {
  const DefectDef({required this.id, required this.label});

  final int id;
  final String label;
}
