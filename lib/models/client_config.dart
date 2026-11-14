/// Цены, лимиты и минимальная сборка с сервера (GET /config): меняются в .env бекенда без
/// релиза приложения, поэтому здесь не хранятся.
class ClientConfig {
  const ClientConfig({
    this.inspectionPlacementFee = 0,
    this.selectionPlacementFee = 0,
    this.inspectionMaxDaysAhead = 10,
    this.vinReportPrice,
    this.minBuild = 0,
  });

  /// Комиссия за размещение разового осмотра, ₽; 0 — бесплатно.
  final int inspectionPlacementFee;

  /// Комиссия за размещение подбора, ₽; 0 — бесплатно.
  final int selectionPlacementFee;

  /// На сколько дней вперёд можно назначить осмотр.
  final int inspectionMaxDaysAhead;
  final int? vinReportPrice;

  /// Минимальная сборка: своя старее — экран «Обновите приложение»
  /// (`AppUpdate`). 0 — без проверки.
  final int minBuild;

  factory ClientConfig.fromJson(Map<String, dynamic> json) => ClientConfig(
    inspectionPlacementFee: json['inspection_placement_fee'] as int? ?? 0,
    selectionPlacementFee: json['selection_placement_fee'] as int? ?? 0,
    inspectionMaxDaysAhead: json['inspection_max_days_ahead'] as int? ?? 10,
    vinReportPrice: json['vin_report_price'] as int?,
    minBuild: json['min_build'] as int? ?? 0,
  );
}
