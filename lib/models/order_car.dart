import 'inspection_outcome.dart';
import 'inspection_panel.dart' show mediaUrl;
import 'inspection_verdict.dart';
import 'vin_kind.dart';

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
    this.vinKind,
    this.vinPhotoUrl,
    this.vinMismatch = false,
    this.mileageKm,
    this.customerMileageKm,
    this.mileageMismatch = false,
    this.odometerPhotoUrl,
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

  /// Что исполнитель снял с таблички; null — ещё не снимал.
  final VinKind? vinKind;

  /// Фото таблички — подписанная ссылка (Bearer не нужен), живёт около часа.
  final String? vinPhotoUrl;

  /// Заказчик указал один VIN, а исполнитель снял с машины другой.
  final bool vinMismatch;

  /// Пробег по одометру — снял исполнитель. null, пока осмотр не начат.
  final int? mileageKm;

  /// Пробег со слов продавца — указал заказчик разового осмотра.
  final int? customerMileageKm;

  /// Одометр и слова продавца расходятся заметно — порог считает сервер.
  final bool mileageMismatch;

  /// Фото приборки — подписанная ссылка, живёт около часа.
  final String? odometerPhotoUrl;

  final int? inspectionId;
  final String? inspectionStatus;
  final InspectionOutcome? inspectionOutcome;

  /// Вердикт разового осмотра — у кандидатов подбора его нет.
  final InspectionVerdict? verdict;
  final String? verdictComment;

  String get title => '$brand $model $year';

  /// Подпись в списке кандидатов: исход покупки важнее вердикта, вердикт —
  /// статуса осмотра. Статус у бекенда — строка без энама, незнакомое
  /// значение не выводим как есть.
  String get inspectionLabel {
    if (inspectionOutcome != null) return inspectionOutcome!.label;
    if (verdict != null) return verdict!.label.toLowerCase();
    if (inspectionId == null) return 'осмотр не начат';
    return switch (inspectionStatus) {
      'in_progress' => 'идёт осмотр',
      'completed' => 'осмотрена',
      _ => 'осмотр',
    };
  }

  factory OrderCar.fromJson(Map<String, dynamic> json) {
    final inspection = json['inspection'] as Map<String, dynamic>?;
    return OrderCar(
      id: json['id'] as int,
      brand: json['brand'] as String,
      model: json['model'] as String,
      year: json['year'] as int,
      vinMasked: json['vin_masked'] as String,
      vinKind: vinKindFromApi(json['vin_kind'] as String?),
      vinPhotoUrl: mediaUrl(json['vin_photo_url'] as String?),
      vinMismatch: json['vin_mismatch'] as bool? ?? false,
      mileageKm: json['mileage_km'] as int?,
      customerMileageKm: json['customer_mileage_km'] as int?,
      mileageMismatch: json['mileage_mismatch'] as bool? ?? false,
      odometerPhotoUrl: mediaUrl(json['odometer_photo_url'] as String?),
      inspectionId: inspection?['id'] as int?,
      inspectionStatus: inspection?['status'] as String?,
      inspectionOutcome: inspectionOutcomeFromApi(
        inspection?['outcome'] as String?,
      ),
      verdict: inspectionVerdictFromApi(inspection?['verdict'] as String?),
      verdictComment: inspection?['verdict_comment'] as String?,
    );
  }
}
