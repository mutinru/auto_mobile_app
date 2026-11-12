import '../models/payment.dart';
import 'api_client.dart';
import 'payment_repository.dart';

/// Платежи (/payments): состояние и токен формы SDK.
class ApiPaymentRepository implements PaymentRepository {
  ApiPaymentRepository(this._client);

  final ApiClient _client;

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
