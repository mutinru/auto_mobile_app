import '../models/payment.dart';
import 'api_client.dart';
import 'json_list.dart';
import 'payment_repository.dart';

/// Платежи (/payments): состояние и токен формы SDK.
class ApiPaymentRepository implements PaymentRepository {
  ApiPaymentRepository(this._client);

  final ApiClient _client;

  @override
  Future<PaymentPage> fetchPayments({int page = 1}) async {
    final json = await _client.get('/payments?page=$page');
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    return PaymentPage(
      items: parseList(json['data'], Payment.fromJson, what: 'платежи'),
      hasMore:
          ((meta['current_page'] as num?)?.toInt() ?? 1) <
          ((meta['last_page'] as num?)?.toInt() ?? 1),
    );
  }

  @override
  Future<Payment> fetchPayment(int id) async {
    final json = await _client.get('/payments/$id');
    return Payment.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<Payment> submitPaymentToken(
    int paymentId, {
    required String token,
    required String methodType,
  }) async {
    final json = await _client.post('/payments/$paymentId/token', {
      'payment_token': token,
      'payment_method_type': methodType,
    });
    return Payment.fromJson(json['data'] as Map<String, dynamic>);
  }
}
