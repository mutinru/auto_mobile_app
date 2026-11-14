/// Платёж — зеркалит PaymentResource на бекенде. Провайдера приложение не
/// знает: что делать, говорит [checkout] (App\Payments\Checkout).
class Payment {
  const Payment({
    required this.id,
    required this.status,
    required this.amount,
    this.refundedAmount = 0,
    this.purpose,
    this.orderId,
    this.checkout,
    this.confirmationUrl,
    this.methodType,
  });

  final int id;
  final PaymentStatus status;

  /// Сумма, ₽.
  final int amount;
  final int refundedAmount;

  /// vin_report | inspection_placement | selection_placement; null — сервер
  /// не сказал.
  final String? purpose;
  final int? orderId;

  /// С чего начать оплату — только пока платёж ждёт её.
  final PaymentCheckout? checkout;

  /// Куда отправить плательщика подтвердить оплату (3-D Secure, SberPay,
  /// СБП) — у SDK после токена, у страницы оплаты — сама страница.
  final String? confirmationUrl;

  /// Способ оплаты, выбранный в форме SDK (bank_card, sbp, …).
  final String? methodType;

  bool get isPending => status == PaymentStatus.pending;

  /// Деньги у платформы: удержаны (размещение до отчёта) или списаны.
  bool get holdsMoney =>
      status == PaymentStatus.authorized || status == PaymentStatus.paid;

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    id: json['id'] as int,
    status: paymentStatusFromApi(json['status'] as String?),
    amount: json['amount'] as int,
    refundedAmount: json['refunded_amount'] as int? ?? 0,
    purpose: json['purpose'] as String?,
    orderId: json['order_id'] as int?,
    checkout: json['checkout'] is Map<String, dynamic>
        ? PaymentCheckout.fromJson(json['checkout'] as Map<String, dynamic>)
        : null,
    confirmationUrl: json['confirmation_url'] as String?,
    methodType: json['payment_method_type'] as String?,
  );
}

/// Статус платежа — зеркало констант App\Models\Payment.
enum PaymentStatus {
  pending,

  /// Деньги удержаны: спишутся, когда исполнитель пришлёт отчёт.
  authorized,
  paid,

  /// Удержание снято — деньги вернулись без списания.
  voided,
  canceled,

  /// Статус, о котором эта сборка не знает.
  unknown,
}

PaymentStatus paymentStatusFromApi(String? value) => switch (value) {
  'pending' => PaymentStatus.pending,
  'authorized' => PaymentStatus.authorized,
  'paid' => PaymentStatus.paid,
  'voided' => PaymentStatus.voided,
  'canceled' => PaymentStatus.canceled,
  _ => PaymentStatus.unknown,
};

/// Как начать оплату — зеркало App\Payments\Checkout (sdk | redirect | paid).
enum CheckoutMethod {
  /// Платёжная форма провайдера в приложении (ЮKassa SDK) → токен на сервер.
  sdk,

  /// Страница оплаты у провайдера по ссылке.
  redirect,

  /// Уже оплачено (заглушка сервера).
  paid,

  /// Способ, о котором эта сборка не знает — нужно обновить приложение.
  unknown,
}

CheckoutMethod checkoutMethodFromApi(String? value) => switch (value) {
  'sdk' => CheckoutMethod.sdk,
  'redirect' => CheckoutMethod.redirect,
  'paid' => CheckoutMethod.paid,
  _ => CheckoutMethod.unknown,
};

/// Параметры начала оплаты. Для [CheckoutMethod.sdk] — форма провайдера:
/// ключ мобильного SDK (не секрет — им можно только токенизировать карту),
/// магазин, сумма и способы оплаты. Секретов сервер сюда не кладёт.
class PaymentCheckout {
  const PaymentCheckout({
    required this.method,
    this.provider,
    this.clientKey,
    this.shopId,
    this.title,
    this.amount,
    this.paymentMethods = const [],
    this.userPhone,
    this.tokenSubmitted = false,
  });

  final CheckoutMethod method;

  /// yookassa — какой SDK открывать.
  final String? provider;
  final String? clientKey;
  final String? shopId;
  final String? title;
  final int? amount;

  /// bank_card, sberbank, sbp, yoo_money — как в API провайдера.
  final List<String> paymentMethods;
  final String? userPhone;

  /// Токен уже принят: форма не нужна, остаётся подтверждение.
  final bool tokenSubmitted;

  factory PaymentCheckout.fromJson(Map<String, dynamic> json) =>
      PaymentCheckout(
        method: checkoutMethodFromApi(json['method'] as String?),
        provider: json['provider'] as String?,
        clientKey: json['client_key'] as String?,
        shopId: json['shop_id'] as String?,
        title: json['title'] as String?,
        amount: json['amount'] as int?,
        paymentMethods:
            (json['payment_methods'] as List?)?.cast<String>() ?? const [],
        userPhone: json['user_phone'] as String?,
        tokenSubmitted: json['token_submitted'] as bool? ?? false,
      );
}
