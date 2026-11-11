import 'inspection_verdict.dart';
import 'order_car.dart';

/// Свой готовый осмотр исполнителя, который можно прикрепить к подбору
/// вместо нового выезда (`GET /orders/{id}/library`). Что сюда попадает,
/// решает только сервер (`App\Queries\InspectionLibrary`): свой осмотр
/// подбора с вердиктом, не старше [InspectionLibraryPage.days] дней, машина
/// нигде не куплена.
class LibraryInspection {
  const LibraryInspection({
    required this.inspectionId,
    required this.car,
    this.verdict,
    this.verdictComment,
    this.completedAt,
    this.city,
  });

  final int inspectionId;

  /// Машина без блока осмотра — поля осмотра у неё пустые, они здесь.
  final OrderCar car;
  final InspectionVerdict? verdict;
  final String? verdictComment;
  final DateTime? completedAt;

  /// Город подбора, под который делали осмотр.
  final String? city;

  factory LibraryInspection.fromJson(Map<String, dynamic> json) {
    final inspection = json['inspection'] as Map<String, dynamic>;
    return LibraryInspection(
      inspectionId: inspection['id'] as int,
      car: OrderCar.fromJson(json['car'] as Map<String, dynamic>),
      verdict: inspectionVerdictFromApi(inspection['verdict'] as String?),
      verdictComment: inspection['verdict_comment'] as String?,
      completedAt: DateTime.tryParse(
        inspection['completed_at'] as String? ?? '',
      )?.toLocal(),
      city: json['city'] as String?,
    );
  }
}

/// Ответ библиотеки: осмотры и срок, за который они годятся. Срок — с
/// сервера (`InspectionLibrary::DAYS`), не хардкодь его.
class InspectionLibraryPage {
  const InspectionLibraryPage({required this.items, required this.days});

  final List<LibraryInspection> items;
  final int days;

  factory InspectionLibraryPage.fromJson(Map<String, dynamic> json) =>
      InspectionLibraryPage(
        items: [
          for (final item in json['data'] as List)
            LibraryInspection.fromJson(item as Map<String, dynamic>),
        ],
        days: json['days'] as int,
      );
}
