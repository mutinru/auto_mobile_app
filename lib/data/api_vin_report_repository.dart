import '../models/vin_report.dart';
import 'api_client.dart';
import 'json_list.dart';
import 'vin_report_repository.dart';

/// Отчёты по VIN (/vin-reports): проверка, покупка, купленные пакеты.
class ApiVinReportRepository implements VinReportRepository {
  ApiVinReportRepository(this._client);

  final ApiClient _client;

  @override
  Future<VinReportCheck> checkVinReports(String vin) async {
    final json = await _client.get(
      '/vin-reports/check?vin=${Uri.encodeQueryComponent(vin)}',
    );
    return VinReportCheck.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<VinReportPurchase> purchaseVinReport(String vin) async {
    final json = await _client.post('/vin-reports/purchases', {'vin': vin});
    return VinReportPurchase.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<VinReportPurchase>> fetchVinReportPurchases() async {
    final json = await _client.get('/vin-reports/purchases');
    return parseList(
      json['data'],
      VinReportPurchase.fromJson,
      what: 'купленный отчёт',
    );
  }

  @override
  Future<VinReportPurchase> fetchVinReportPurchase(int id) async {
    final json = await _client.get('/vin-reports/purchases/$id');
    return VinReportPurchase.fromJson(json['data'] as Map<String, dynamic>);
  }
}
