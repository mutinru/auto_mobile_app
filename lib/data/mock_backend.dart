import '../models/inspection_verdict.dart';
import '../models/order.dart';
import '../models/order_status.dart';
import '../models/payment.dart';
import '../models/vin_report.dart';
import 'mock_fixtures.dart';
import 'mock_order_repository.dart';

/// Общий мир моков (ревью №39) — как база на сервере: заказы, платежи,
/// покупки по VIN. Моки репозиториев над ним — поведение эндпоинтов;
/// побочные эффекты оплаты (размещение публикует заказ, VIN закрывает
/// покупку) — здесь, как `Payable` на бекенде.
class MockBackend {
  /// [orders] — свой набор вместо общей фикстуры [MockFixtures.orders].
  MockBackend({List<Order>? orders}) : orders = orders ?? MockFixtures.orders();

  final List<Order> orders;

  /// Комиссия за размещение осмотра, как INSPECTION_PLACEMENT_FEE на
  /// сервере: 0 — заказ публикуется сразу, иначе ждёт оплаты.
  int placementFee = 0;

  /// Комиссия за размещение подбора, как SELECTION_PLACEMENT_FEE.
  int selectionPlacementFee = 0;

  /// Платежи мока: оплата формы SDK (submitPaymentToken) проходит сразу —
  /// размещение удерживается и публикует заказ, VIN — списывается.
  final Map<int, Payment> payments = {};
  int _paymentSeq = 900;

  Payment startPayment(int amount, String purpose, {int? orderId}) {
    final payment = Payment(
      id: ++_paymentSeq,
      status: PaymentStatus.pending,
      amount: amount,
      purpose: purpose,
      orderId: orderId,
      checkout: PaymentCheckout(
        method: CheckoutMethod.sdk,
        provider: 'yookassa',
        clientKey: 'test_client_key',
        shopId: '000000',
        title: purpose == 'vin_report'
            ? 'Готовые отчёты по VIN'
            : 'Размещение осмотра',
        amount: amount,
        paymentMethods: const ['bank_card', 'sberbank', 'sbp'],
      ),
    );
    payments[payment.id] = payment;
    return payment;
  }

  /// Сохранить заказ и отдать его с картой действий, как сервер.
  Order replaceOrder(Order updated) {
    // карта действий — правило мока заказов, общее для всех его путей
    // ignore: invalid_use_of_visible_for_testing_member
    final stored = MockOrderRepository.withActions(updated);
    final i = orders.indexWhere((o) => o.id == stored.id);
    if (i != -1) orders[i] = stored;
    return stored;
  }

  // --- отчёты по VIN ---

  /// Разные VIN, проверенные за «сутки», — лимит как у сервера.
  final checkedVins = <String>{};

  /// Оплаченные пакеты.
  final vinPurchases = <VinReportPurchase>[];

  /// false — покупка по VIN ждёт оплаты формой SDK, как с провайдером на
  /// сервере; true — оплачена сразу, как с заглушкой.
  bool vinReportPaidInstantly = true;

  /// Покупки, ждущие оплаты: id платежа → покупка.
  final Map<int, VinReportPurchase> unpaidVinPurchases = {};

  VinReportPurchase vinPurchase(String vin, {required bool paid}) =>
      VinReportPurchase(
        id: 701,
        vinMasked: '··· ${vin.substring(vin.length - 6)}',
        paid: paid,
        price: 299,
        paidAt: paid ? DateTime(2026, 11, 3) : null,
        items: [
          for (final (i, item) in MockFixtures.reportItems.indexed)
            VinReportItem(
              date: item.date,
              city: item.city,
              mileageKm: item.mileageKm,
              // как сервер: до оплаты без вердикта и id осмотра
              inspectionId: paid ? 9001 + i : null,
              brand: 'Volkswagen',
              model: 'Tiguan',
              year: 2019,
              verdict: !paid
                  ? null
                  : i == 0
                  ? InspectionVerdict.withReservations
                  : InspectionVerdict.recommended,
              verdictComment: paid && i == 0 ? 'Перекрашено крыло' : null,
            ),
        ],
      );

  /// Платёж проведён формой SDK — как сервер: размещение удерживается и
  /// публикует заказ (Order::paymentSucceeded), VIN списывается и закрывает
  /// покупку.
  Payment settle(Payment payment, {required String methodType}) {
    final placement =
        payment.purpose == 'inspection_placement' ||
        payment.purpose == 'selection_placement';
    final done = Payment(
      id: payment.id,
      status: placement ? PaymentStatus.authorized : PaymentStatus.paid,
      amount: payment.amount,
      purpose: payment.purpose,
      orderId: payment.orderId,
      methodType: methodType,
    );
    payments[payment.id] = done;
    if (placement && payment.orderId != null) {
      final order = orders.firstWhere((o) => o.id == payment.orderId);
      replaceOrder(
        order.copyWith(
          status: OrderStatus.awaitingExecutor,
          clearPendingPayment: true,
        ),
      );
    }
    if (payment.purpose == 'vin_report' &&
        unpaidVinPurchases.remove(payment.id) != null) {
      vinPurchases.add(vinPurchase(MockFixtures.reportVin, paid: true));
    }
    return done;
  }
}
