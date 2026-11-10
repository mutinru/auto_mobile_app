/// Цены и лимиты с сервера (GET /config): меняются в .env бекенда без
/// релиза приложения, поэтому здесь не хранятся.
class ClientConfig {
  const ClientConfig({
    this.inspectionPlacementFee = 0,
    this.inspectionMaxDaysAhead = 10,
    this.vinReportPrice,
  });

  /// Комиссия за размещение разового осмотра, ₽; 0 — бесплатно.
  final int inspectionPlacementFee;

  /// На сколько дней вперёд можно назначить осмотр.
  final int inspectionMaxDaysAhead;
  final int? vinReportPrice;

  factory ClientConfig.fromJson(Map<String, dynamic> json) => ClientConfig(
    inspectionPlacementFee: json['inspection_placement_fee'] as int? ?? 0,
    inspectionMaxDaysAhead: json['inspection_max_days_ahead'] as int? ?? 10,
    vinReportPrice: json['vin_report_price'] as int?,
  );
}
