/// Сводка отчёта до оплаты — только количества: вердикт и состояния деталей
/// заказчик увидит после подтверждения оплаты (Order::reportSummary на бекенде).
class ReportSummary {
  const ReportSummary({
    required this.panelsTotal,
    required this.panelsInspected,
    required this.defectsCount,
    required this.photosCount,
  });

  final int panelsTotal;
  final int panelsInspected;
  final int defectsCount;
  final int photosCount;

  factory ReportSummary.fromJson(Map<String, dynamic> json) => ReportSummary(
        panelsTotal: json['panels_total'] as int? ?? 0,
        panelsInspected: json['panels_inspected'] as int? ?? 0,
        defectsCount: json['defects_count'] as int? ?? 0,
        photosCount: json['photos_count'] as int? ?? 0,
      );
}

/// Спор об оплате разового осмотра. Разбирает поддержка.
class OrderDispute {
  const OrderDispute({required this.openedBy, required this.reason, this.openedAt});

  /// id пользователя, открывшего спор.
  final int openedBy;
  final String reason;
  final DateTime? openedAt;

  factory OrderDispute.fromJson(Map<String, dynamic> json) => OrderDispute(
        openedBy: json['opened_by'] as int,
        reason: json['reason'] as String? ?? '',
        openedAt: json['opened_at'] != null
            ? DateTime.parse(json['opened_at'] as String).toLocal()
            : null,
      );
}
