import '../models/payment.dart';

/// Платежи: состояние и токен формы SDK. Платёж начинает действие домена
/// (размещение, покупка отчёта), проводит — только PaymentFlow.
abstract class PaymentRepository {
  /// Платёж; ждущий оплаты сервер перед ответом сверяет с провайдером.
  Future<Payment> fetchPayment(int id);

  /// Токен из платёжной формы SDK: сервер создаёт платёж у провайдера и
  /// отдаёт его — с confirmationUrl, если нужно подтверждение.
  Future<Payment> submitPaymentToken(
    int paymentId, {
    required String token,
    required String methodType,
  });
}
