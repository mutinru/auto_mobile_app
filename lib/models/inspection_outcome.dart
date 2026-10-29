/// Исход кандидата подбора после «Зафиксировать покупку» — зеркалит
/// App\Enums\InspectionOutcome.
enum InspectionOutcome { purchased, rejected }

extension InspectionOutcomeX on InspectionOutcome {
  String get label => switch (this) {
        InspectionOutcome.purchased => 'куплена',
        InspectionOutcome.rejected => 'не подошла',
      };
}

InspectionOutcome? inspectionOutcomeFromApi(String? value) => switch (value) {
      'purchased' => InspectionOutcome.purchased,
      'rejected' => InspectionOutcome.rejected,
      _ => null,
    };
