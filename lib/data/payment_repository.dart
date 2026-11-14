import '../models/payment.dart';

/// Платежи: состояние и токен формы SDK. Платёж начинает действие домена
/// (размещение, покупка отчёта), проводит — только PaymentFlow.
abstract class PaymentRepository {
  /// «Мои платежи» с чеками — страница [page], новые сверху. Начатые и
  /// брошенные сервер не отдаёт.
  Future<PaymentPage> fetchPayments({int page = 1});

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

/// Страница «Моих платежей».
class PaymentPage {
  const PaymentPage({required this.items, required this.hasMore});

  final List<Payment> items;
  final bool hasMore;
}
