import 'api_exception.dart';
import '../models/payment.dart';
import 'mock_backend.dart';
import 'payment_repository.dart';

/// Платежи для тестов (ревью №39): оплата формы SDK проходит сразу, а её
/// последствия (опубликовать заказ, закрыть покупку по VIN) делает
/// [MockBackend.settle] — как Payable на сервере.
class MockPaymentRepository implements PaymentRepository {
  MockPaymentRepository(this.backend);

  final MockBackend backend;

  @override
  Future<Payment> fetchPayment(int id) async {
    final payment = backend.payments[id];
    if (payment == null) throw ApiException(404, '{"message":"Не найдено"}');
    return payment;
  }

  @override
  Future<Payment> submitPaymentToken(
    int paymentId, {
    required String token,
    required String methodType,
  }) async {
    final payment = await fetchPayment(paymentId);
    if (!payment.isPending) {
      throw ApiException(422, '{"message":"Платёж уже не ждёт оплаты"}');
    }
    return backend.settle(payment, methodType: methodType);
  }
}
