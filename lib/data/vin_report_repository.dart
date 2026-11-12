import '../models/vin_report.dart';

/// Готовые отчёты по VIN: проверка перед заказом осмотра, покупка пакета и
/// купленные пакеты. Оплату покупки проводит PaymentFlow.
abstract class VinReportRepository {
  /// Готовые отчёты по VIN (или номеру кузова): тизер без вердикта и цена.
  /// Сервер считает разные VIN — не больше 15 в сутки, сверх — 429.
  Future<VinReportCheck> checkVinReports(String vin);

  /// Купить пакет готовых отчётов по VIN. С заглушкой оплаты сервера —
  /// сразу оплачено; с провайдером — неоплаченная покупка с
  /// [VinReportPurchase.payment], его проводит PaymentFlow.
  Future<VinReportPurchase> purchaseVinReport(String vin);

  /// Оплаченные пакеты заказчика, свежие сверху.
  Future<List<VinReportPurchase>> fetchVinReportPurchases();

  Future<VinReportPurchase> fetchVinReportPurchase(int id);
}
