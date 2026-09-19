/// Тип осмотра — совпадает с App\Enums\InspectionType на бекенде.
/// Подписи взяты из чипов экрана «Старт осмотра» в макете.
enum InspectionType { full, express, bodyOnly, prePurchase }

extension InspectionTypeX on InspectionType {
  String get label => switch (this) {
        InspectionType.full => 'Полный · 13 деталей',
        InspectionType.express => 'Экспресс',
        InspectionType.bodyOnly => 'Кузов',
        InspectionType.prePurchase => 'Перед покупкой',
      };

  String get apiValue => switch (this) {
        InspectionType.full => 'full',
        InspectionType.express => 'express',
        InspectionType.bodyOnly => 'body_only',
        InspectionType.prePurchase => 'pre_purchase',
      };
}
