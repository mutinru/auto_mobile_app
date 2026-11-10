import 'inspection_verdict.dart';
import 'payment.dart';

/// Осмотр в предложении или пакете готовых отчётов по VIN. До оплаты
/// сервер не отдаёт [verdict] и [inspectionId] — они и есть товар.
class VinReportItem {
  const VinReportItem({
    this.date,
    this.city,
    this.mileageKm,
    this.inspectionId,
    this.brand,
    this.model,
    this.year,
    this.verdict,
    this.verdictComment,
  });

  final DateTime? date;
  final String? city;
  final int? mileageKm;
  final int? inspectionId;
  final String? brand;
  final String? model;
  final int? year;
  final InspectionVerdict? verdict;
  final String? verdictComment;

  String? get carTitle => brand == null
      ? null
      : [brand, model, if (year != null) '$year'].whereType<String>().join(' ');

  factory VinReportItem.fromJson(Map<String, dynamic> json) => VinReportItem(
    date: DateTime.tryParse(json['date'] as String? ?? ''),
    city: json['city'] as String?,
    mileageKm: json['mileage_km'] as int?,
    inspectionId: json['inspection_id'] as int?,
    brand: json['brand'] as String?,
    model: json['model'] as String?,
    year: json['year'] as int?,
    verdict: inspectionVerdictFromApi(json['verdict'] as String?),
    verdictComment: json['verdict_comment'] as String?,
  );
}

/// Ответ проверки VIN (`GET /vin-reports/check`): есть ли готовые
/// отчёты, тизер и цена. [purchaseId] — пакет уже куплен этим заказчиком.
class VinReportCheck {
  const VinReportCheck({
    required this.vin,
    required this.items,
    required this.price,
    this.purchaseId,
  });

  final String vin;
  final List<VinReportItem> items;
  final int price;
  final int? purchaseId;

  bool get available => items.isNotEmpty;

  factory VinReportCheck.fromJson(Map<String, dynamic> json) => VinReportCheck(
    vin: json['vin'] as String,
    items: [
      for (final i in json['items'] as List? ?? const [])
        VinReportItem.fromJson(i as Map<String, dynamic>),
    ],
    price: json['price'] as int,
    purchaseId: json['purchase_id'] as int?,
  );
}

/// Купленный пакет отчётов по одному VIN.
class VinReportPurchase {
  const VinReportPurchase({
    required this.id,
    required this.vinMasked,
    required this.paid,
    required this.price,
    required this.items,
    this.paidAt,
    this.payment,
  });

  final int id;
  final String vinMasked;
  final bool paid;
  final int price;
  final List<VinReportItem> items;
  final DateTime? paidAt;

  /// Платёж до оплаты — с чего начать или продолжить её (PaymentFlow).
  /// У оплаченной покупки и при оплате заглушкой сервера — null.
  final Payment? payment;

  /// Машина пакета — у всех осмотров одна, берём из первого.
  String? get carTitle => items.firstOrNull?.carTitle;

  factory VinReportPurchase.fromJson(Map<String, dynamic> json) =>
      VinReportPurchase(
        id: json['id'] as int,
        vinMasked: json['vin_masked'] as String,
        paid: json['status'] == 'paid',
        price: json['price'] as int,
        paidAt: DateTime.tryParse(json['paid_at'] as String? ?? ''),
        payment: json['payment'] is Map<String, dynamic>
            ? Payment.fromJson(json['payment'] as Map<String, dynamic>)
            : null,
        items: [
          for (final i in json['inspections'] as List? ?? const [])
            VinReportItem.fromJson(i as Map<String, dynamic>),
        ],
      );
}
