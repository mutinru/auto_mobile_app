import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/order_repository.dart';
import '../models/payment.dart';
import '../widgets/api_error.dart';
import 'payment_sdk.dart';

/// Чем кончилась оплата для экрана.
enum PaymentOutcome {
  /// Деньги у платформы — удержаны или списаны.
  paid,

  /// Сервер ещё не знает итога (банк думает) — статус обновится сам.
  pending,

  /// Пользователь закрыл форму — ничего не случилось.
  dismissed,

  /// Оплата не прошла (отказ банка, отменена).
  declined,

  /// Сбой связи или формы.
  failed,

  /// Сервер прислал способ оплаты, которого эта сборка не знает.
  needsUpdate,
}

class PaymentResult {
  const PaymentResult(this.outcome, {this.payment, this.error});

  final PaymentOutcome outcome;

  /// Последнее, что известно о платеже с сервера.
  final Payment? payment;
  final Object? error;
}

/// Открыть страницу оплаты и дождаться, пока пользователь вернётся.
typedef PaymentPageOpener = Future<void> Function(Uri url);

/// Проводит платёж по [Payment.checkout] — какой провайдер, решает сервер:
///
///  - sdk      — форма SDK → токен на сервер → подтверждение SDK по ссылке;
///  - redirect — страница оплаты во встроенном браузере;
///  - paid     — уже оплачено.
///
/// Итог всегда — с сервера (GET /payments/{id}), клиентскому колбэку SDK
/// не верим. Если Android убьёт процесс посреди оплаты (ушли в банк), итог
/// не потеряется: сервер узнает его вебхуком, а заказ и покупка покажут
/// новый статус при следующем чтении.
class PaymentFlow {
  PaymentFlow(
    this._repository, {
    PaymentSdk? sdk,
    PaymentPageOpener? openPage,
    this.pollDelay = const Duration(seconds: 2),
    this.pollAttempts = 10,
  }) : _sdk = sdk ?? PaymentFlow.sdk,
       _openPage = openPage ?? PaymentFlow.openPage;

  /// Форма SDK по умолчанию; виджет-тесты подменяют (плагина в них нет).
  static PaymentSdk sdk = const YooKassaSdk();

  /// Страница оплаты по умолчанию; виджет-тесты подменяют.
  static PaymentPageOpener openPage = _openInAppBrowser;

  final OrderRepository _repository;
  final PaymentSdk _sdk;
  final PaymentPageOpener _openPage;
  final Duration pollDelay;
  final int pollAttempts;

  Future<PaymentResult> run(Payment payment) async {
    try {
      return await _run(payment);
    } catch (e) {
      return PaymentResult(PaymentOutcome.failed, payment: payment, error: e);
    }
  }

  Future<PaymentResult> _run(Payment payment) async {
    if (!payment.isPending) return _result(payment);
    final checkout = payment.checkout;

    switch (checkout?.method) {
      case CheckoutMethod.paid:
        return _result(await _poll(payment));

      case CheckoutMethod.sdk when checkout!.provider == YooKassaSdk.provider:
        var current = payment;
        var methodType = payment.methodType;
        if (!checkout.tokenSubmitted) {
          final token = await _sdk.tokenize(payment);
          switch (token) {
            case SdkCanceled():
              return PaymentResult(PaymentOutcome.dismissed, payment: payment);
            case SdkFailed(:final message):
              return PaymentResult(
                PaymentOutcome.failed,
                payment: payment,
                error: message,
              );
            case SdkToken():
              methodType = token.methodType;
              current = await _repository.submitPaymentToken(
                payment.id,
                token: token.token,
                methodType: token.methodType,
              );
          }
        }
        final url = current.confirmationUrl;
        if (current.isPending && url != null) {
          await _sdk.confirm(
            current,
            url: url,
            methodType: methodType ?? 'bank_card',
          );
        }
        return _result(await _poll(current));

      case CheckoutMethod.redirect:
        final url = payment.confirmationUrl;
        if (url == null) {
          return PaymentResult(PaymentOutcome.failed, payment: payment);
        }
        await _openPage(Uri.parse(url));
        return _result(await _poll(payment));

      default:
        return PaymentResult(PaymentOutcome.needsUpdate, payment: payment);
    }
  }

  /// Перечитывать, пока сервер не узнает итог (или не кончатся попытки).
  Future<Payment> _poll(Payment payment) async {
    var current = await _repository.fetchPayment(payment.id);
    for (var i = 1; i < pollAttempts && current.isPending; i++) {
      await Future<void>.delayed(pollDelay);
      current = await _repository.fetchPayment(payment.id);
    }
    return current;
  }

  static PaymentResult _result(Payment payment) => PaymentResult(
    switch (payment.status) {
      PaymentStatus.authorized || PaymentStatus.paid => PaymentOutcome.paid,
      PaymentStatus.pending => PaymentOutcome.pending,
      PaymentStatus.canceled || PaymentStatus.voided => PaymentOutcome.declined,
      PaymentStatus.unknown => PaymentOutcome.needsUpdate,
    },
    payment: payment,
  );

  /// Custom Tabs: у SberPay и СБП переходы в банк из WebView ломаются.
  /// Ждём возврата в приложение — тогда сервер уже может знать итог.
  static Future<void> _openInAppBrowser(Uri url) async {
    final returned = Completer<void>();
    final listener = AppLifecycleListener(
      onResume: () {
        if (!returned.isCompleted) returned.complete();
      },
    );
    try {
      final ok = await launchUrl(url, mode: LaunchMode.inAppBrowserView);
      if (!ok) throw Exception('Не удалось открыть страницу оплаты');
      await returned.future.timeout(const Duration(minutes: 20));
    } on TimeoutException {
      // вернулись иначе — итог всё равно спросим у сервера
    } finally {
      listener.dispose();
    }
  }
}

/// Провести оплату с экрана; не оплачено — сообщение. Кнопка экрана
/// крутит спиннер, пока идёт оплата и сверка с сервером. По итогу экран
/// перечитывает заказ или покупку.
Future<PaymentOutcome> runPayment(
  BuildContext context,
  OrderRepository repository,
  Payment payment,
) async {
  final result = await PaymentFlow(repository).run(payment);
  if (!context.mounted) return result.outcome;

  final text = switch (result.outcome) {
    PaymentOutcome.paid || PaymentOutcome.dismissed => null,
    PaymentOutcome.pending =>
      'Банк ещё проверяет оплату — статус обновится сам',
    PaymentOutcome.declined => 'Оплата не прошла — попробуйте ещё раз',
    PaymentOutcome.needsUpdate =>
      'Этот способ оплаты не поддерживается — обновите приложение',
    PaymentOutcome.failed => switch (result.error) {
      final Object e when e is! String =>
        'Не удалось провести оплату: ${apiErrorText(e)}',
      _ => 'Не удалось открыть оплату — попробуйте ещё раз',
    },
  };
  if (text != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
  return result.outcome;
}
