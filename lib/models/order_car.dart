import 'inspection_verdict.dart';

/// Кандидат в рамках заказа (CarResource на бекенде, с id и статусом
/// осмотра) — не путать с models/car.dart, тем описывается автомобиль
/// уже начатого одиночного осмотра.
class OrderCar {
  const OrderCar({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.vinMasked,
    required this.mileageKm,
    this.inspectionId,
    this.inspectionStatus,
    this.inspectionOutcome,
    this.verdict,
    this.verdictComment,
  });

  final int id;
  final String brand;
  final String model;
  final int year;
  final String vinMasked;
  final int mileageKm;

  final int? inspectionId;
  final String? inspectionStatus;
  final String? inspectionOutcome;

  /// Вердикт разового осмотра — у кандидатов подбора его нет.
  final InspectionVerdict? verdict;
  final String? verdictComment;

  String get title => '$brand $model $year';

  factory OrderCar.fromJson(Map<String, dynamic> json) {
    final inspection = json['inspection'] as Map<String, dynamic>?;
    return OrderCar(
      id: json['id'] as int,
      brand: json['brand'] as String,
      model: json['model'] as String,
      year: json['year'] as int,
      vinMasked: json['vin_masked'] as String,
      mileageKm: json['mileage_km'] as int,
      inspectionId: inspection?['id'] as int?,
      inspectionStatus: inspection?['status'] as String?,
      inspectionOutcome: inspection?['outcome'] as String?,
      verdict: inspectionVerdictFromApi(inspection?['verdict'] as String?),
      verdictComment: inspection?['verdict_comment'] as String?,
    );
  }
}
