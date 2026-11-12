import 'api_exception.dart';
import '../models/vin_report.dart';
import 'mock_backend.dart';
import 'mock_fixtures.dart';
import 'vin_report_repository.dart';

/// Отчёты по VIN для тестов (ревью №39) — поведение сервера над [MockBackend]:
/// готовые отчёты есть только по [MockFixtures.reportVin], лимит 15 VIN в
/// «сутки», без заглушки оплаты покупка ждёт платежа формой SDK.
class MockVinReportRepository implements VinReportRepository {
  MockVinReportRepository(this.backend);

  final MockBackend backend;

  @override
  Future<VinReportCheck> checkVinReports(String vin) async {
    final checked = backend.checkedVins;
    if (!checked.contains(vin) && checked.length >= 15) {
      throw ApiException(
        429,
        '{"message":"Можно проверить 15 VIN в сутки — попробуйте завтра"}',
      );
    }
    checked.add(vin);
    final has = vin == MockFixtures.reportVin;
    return VinReportCheck(
      vin: vin,
      items: has ? MockFixtures.reportItems : const [],
      price: 299,
      purchaseId: has ? backend.vinPurchases.firstOrNull?.id : null,
    );
  }

  @override
  Future<VinReportPurchase> purchaseVinReport(String vin) async {
    if (vin != MockFixtures.reportVin) {
      throw ApiException(422, '{"message":"Готовых отчётов по этому VIN нет"}');
    }
    if (backend.vinPurchases.firstOrNull case final p?) return p;
    if (!backend.vinReportPaidInstantly) {
      final payment = backend.startPayment(299, 'vin_report');
      final unpaid = backend.vinPurchase(vin, paid: false);
      final withPayment = VinReportPurchase(
        id: unpaid.id,
        vinMasked: unpaid.vinMasked,
        paid: false,
        price: unpaid.price,
        items: unpaid.items,
        payment: payment,
      );
      backend.unpaidVinPurchases[payment.id] = withPayment;
      return withPayment;
    }
    final purchase = backend.vinPurchase(vin, paid: true);
    backend.vinPurchases.add(purchase);
    return purchase;
  }

  @override
  Future<List<VinReportPurchase>> fetchVinReportPurchases() async =>
      List.of(backend.vinPurchases);

  @override
  Future<VinReportPurchase> fetchVinReportPurchase(int id) async =>
      backend.vinPurchases.where((p) => p.id == id).firstOrNull ??
      backend.unpaidVinPurchases.values.firstWhere((p) => p.id == id);
}
