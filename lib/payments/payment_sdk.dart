import 'package:yookassa_payments_flutter/yookassa_payments_flutter.dart' as yk;

import '../models/payment.dart';

/// Итог платёжной формы SDK.
sealed class SdkTokenResult {
  const SdkTokenResult();
}

/// Форма отдала одноразовый токен — его проводит сервер.
class SdkToken extends SdkTokenResult {
  const SdkToken(this.token, this.methodType);

  final String token;

  /// Способ оплаты кодом API провайдера: bank_card, sberbank, sbp, …
  final String methodType;
}

/// Пользователь закрыл форму.
class SdkCanceled extends SdkTokenResult {
  const SdkCanceled();
}

/// Форма сломалась (нет сети, неверный ключ). [message] — для логов.
class SdkFailed extends SdkTokenResult {
  const SdkFailed(this.message);

  final String message;
}

/// Платёжная форма провайдера в приложении. Платёж она не создаёт: отдаёт
/// токен, а платёж по нему создаёт сервер (POST /payments/{id}/token).
/// Параметры формы — из [Payment.checkout], ничего не вшито в сборку.
/// В тестах плагина нет — подменяется (PaymentFlow.sdk).
abstract class PaymentSdk {
  Future<SdkTokenResult> tokenize(Payment payment);

  /// Подтверждение (3-D Secure, SberPay, СБП) по ссылке от сервера.
  /// Завершение не значит «оплачено» — итог знает только сервер.
  Future<void> confirm(
    Payment payment, {
    required String url,
    required String methodType,
  });
}

/// ЮKassa — yookassa_payments_flutter поверх нативного SDK.
class YooKassaSdk implements PaymentSdk {
  const YooKassaSdk();

  static const provider = 'yookassa';

  @override
  Future<SdkTokenResult> tokenize(Payment payment) async {
    final c = payment.checkout;
    if (c == null || c.clientKey == null || c.shopId == null) {
      return const SdkFailed('Нет параметров формы оплаты');
    }
    final methods = [
      for (final m in c.paymentMethods) ?_method(m),
    ];
    final result = await yk.YookassaPaymentsFlutter.tokenization(
      yk.TokenizationModuleInputData(
        clientApplicationKey: c.clientKey!,
        shopId: c.shopId!,
        title: 'БитНеБит',
        subtitle: c.title ?? 'Оплата',
        amount: yk.Amount(
          value: '${c.amount ?? payment.amount}.00',
          currency: yk.Currency.rub,
        ),
        savePaymentMethod: yk.SavePaymentMethod.off,
        tokenizationSettings: yk.TokenizationSettings(
          methods.isEmpty
              ? yk.PaymentMethodTypes.all
              : yk.PaymentMethodTypes(methods),
        ),
        userPhoneNumber: c.userPhone,
      ),
    );
    return switch (result) {
      yk.SuccessTokenizationResult(:final token, :final paymentMethodType) =>
        SdkToken(token, _apiValue(paymentMethodType)),
      yk.CanceledTokenizationResult() => const SdkCanceled(),
      yk.ErrorTokenizationResult(:final error) => SdkFailed(error),
      _ => const SdkFailed('Неизвестный ответ формы оплаты'),
    };
  }

  @override
  Future<void> confirm(
    Payment payment, {
    required String url,
    required String methodType,
  }) {
    final c = payment.checkout;
    return yk.YookassaPaymentsFlutter.confirmation(
      url,
      _method(methodType),
      c?.clientKey ?? '',
      c?.shopId ?? '',
    );
  }

  /// Код способа API ЮKassa → способ плагина; незнакомый — без него.
  static yk.PaymentMethod? _method(String value) => switch (value) {
    'bank_card' => yk.PaymentMethod.bankCard,
    'sberbank' => yk.PaymentMethod.sberbank,
    'sbp' => yk.PaymentMethod.sbp,
    'yoo_money' => yk.PaymentMethod.yooMoney,
    'alfa_pay' => yk.PaymentMethod.alfaPay,
    _ => null,
  };

  static String _apiValue(yk.PaymentMethod? method) => switch (method) {
    yk.PaymentMethod.sberbank => 'sberbank',
    yk.PaymentMethod.sbp => 'sbp',
    yk.PaymentMethod.yooMoney => 'yoo_money',
    yk.PaymentMethod.alfaPay => 'alfa_pay',
    yk.PaymentMethod.googlePay => 'google_pay',
    yk.PaymentMethod.applePay => 'apple_pay',
    _ => 'bank_card',
  };
}
