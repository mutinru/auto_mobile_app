import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/notification_type.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/payment.dart';
import 'package:auto_podbor_mobile/models/time_slot.dart';
import 'package:auto_podbor_mobile/payments/payment_flow.dart';
import 'package:auto_podbor_mobile/payments/payment_sdk.dart';
import 'package:auto_podbor_mobile/screens/inspection_order_detail_screen.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/order_card.dart';
import 'package:auto_podbor_mobile/data/mock_backend.dart';
import 'package:auto_podbor_mobile/data/mock_payment_repository.dart';

import 'support/stores.dart';

/// Форма SDK без плагина: отдаёт заданный итог и считает вызовы.
class FakeSdk implements PaymentSdk {
  FakeSdk([this.result = const SdkToken('tok_test', 'bank_card')]);

  SdkTokenResult result;
  int tokenizeCalls = 0;
  final confirmed = <String>[];

  @override
  Future<SdkTokenResult> tokenize(Payment payment) async {
    tokenizeCalls++;
    return result;
  }

  @override
  Future<void> confirm(
    Payment payment, {
    required String url,
    required String methodType,
  }) async => confirmed.add(url);
}

/// Платежи с заданными ответами: ответ токена и чтения задаёт тест.
class ScriptedRepository extends MockPaymentRepository {
  ScriptedRepository({required this.onToken, required this.onFetch})
    : super(MockBackend());

  Payment Function(int id) onToken;
  Payment Function(int id) onFetch;
  int tokens = 0;

  @override
  Future<Payment> submitPaymentToken(
    int paymentId, {
    required String token,
    required String methodType,
  }) async {
    tokens++;
    return onToken(paymentId);
  }

  @override
  Future<Payment> fetchPayment(int id) async => onFetch(id);
}

Payment payment(
  PaymentStatus status, {
  CheckoutMethod method = CheckoutMethod.sdk,
  String provider = 'yookassa',
  String? confirmationUrl,
  bool tokenSubmitted = false,
}) => Payment(
  id: 5,
  status: status,
  amount: 299,
  confirmationUrl: confirmationUrl,
  checkout: status == PaymentStatus.pending
      ? PaymentCheckout(
          method: method,
          provider: provider,
          clientKey: 'k',
          shopId: '1',
          tokenSubmitted: tokenSubmitted,
        )
      : null,
);

void main() {
  group('модели', () {
    test('платёж с формой SDK и незнакомые значения', () {
      final p = Payment.fromJson({
        'id': 12,
        'status': 'pending',
        'amount': 299,
        'refunded_amount': 0,
        'purpose': 'vin_report',
        'checkout': {
          'method': 'sdk',
          'provider': 'yookassa',
          'client_key': 'live_client',
          'shop_id': '123',
          'payment_methods': ['bank_card', 'sbp'],
          'token_submitted': false,
        },
        'confirmation_url': null,
      });
      expect(p.isPending, isTrue);
      expect(p.checkout!.method, CheckoutMethod.sdk);
      expect(p.checkout!.paymentMethods, ['bank_card', 'sbp']);

      expect(checkoutMethodFromApi('crypto'), CheckoutMethod.unknown);
      expect(paymentStatusFromApi('authorized'), PaymentStatus.authorized);
      expect(paymentStatusFromApi('voided'), PaymentStatus.voided);
    });

    test('статусы заказа: ждёт оплаты и незнакомый', () {
      expect(
        orderStatusFromApi('awaiting_placement'),
        OrderStatus.awaitingPlacement,
      );
      expect(
        orderStatusFromApi('awaiting_executor'),
        OrderStatus.awaitingExecutor,
      );
      // сервер новее — не притворяемся «ждёт исполнителя»
      expect(orderStatusFromApi('something_new'), OrderStatus.unknown);
      expect(OrderStatus.unknown.label, 'обновите приложение');
      expect(
        notificationTypeFromApi('order_auto_cancelled'),
        NotificationType.orderAutoCancelled,
      );
    });

    test('заказ с комиссией и начатой оплатой', () {
      final order = Order.fromJson({
        'id': 1,
        'kind': 'inspection',
        'status': 'awaiting_placement',
        'brand': 'Kia',
        'model': 'Rio',
        'customer': {'id': 1, 'name': 'Андрей'},
        'placement_fee': 199,
        'pending_payment': {
          'id': 3,
          'status': 'pending',
          'amount': 199,
          'purpose': 'inspection_placement',
          'checkout': {'method': 'redirect'},
          'confirmation_url': 'https://pay.test/3',
        },
      });
      expect(order.placementFee, 199);
      expect(order.pendingPayment!.checkout!.method, CheckoutMethod.redirect);
    });
  });

  group('PaymentFlow', () {
    test('форма SDK → токен → сервер: оплачено', () async {
      final repo = ScriptedRepository(
        onToken: (_) => payment(PaymentStatus.paid),
        onFetch: (_) => payment(PaymentStatus.paid),
      );
      final sdk = FakeSdk();

      final result = await PaymentFlow(
        repo,
        sdk: sdk,
      ).run(payment(PaymentStatus.pending));

      expect(result.outcome, PaymentOutcome.paid);
      expect(repo.tokens, 1);
      expect(sdk.confirmed, isEmpty);
    });

    test('подтверждение по ссылке, итог — с сервера', () async {
      var reads = 0;
      final repo = ScriptedRepository(
        onToken: (_) => payment(
          PaymentStatus.pending,
          confirmationUrl: 'https://3ds.test',
          tokenSubmitted: true,
        ),
        // банк думает один опрос, потом удержание
        onFetch: (_) => ++reads < 2
            ? payment(PaymentStatus.pending, tokenSubmitted: true)
            : payment(PaymentStatus.authorized),
      );
      final sdk = FakeSdk();

      final result = await PaymentFlow(
        repo,
        sdk: sdk,
        pollDelay: Duration.zero,
      ).run(payment(PaymentStatus.pending));

      expect(sdk.confirmed, ['https://3ds.test']);
      expect(result.outcome, PaymentOutcome.paid);
      expect(reads, 2);
    });

    test('токен уже отправлен — формы нет, только подтверждение', () async {
      final repo = ScriptedRepository(
        onToken: (_) => throw StateError('второй токен'),
        onFetch: (_) => payment(PaymentStatus.paid),
      );
      final sdk = FakeSdk();

      final result = await PaymentFlow(repo, sdk: sdk).run(
        payment(
          PaymentStatus.pending,
          tokenSubmitted: true,
          confirmationUrl: 'https://3ds.test',
        ),
      );

      expect(sdk.tokenizeCalls, 0);
      expect(sdk.confirmed, ['https://3ds.test']);
      expect(result.outcome, PaymentOutcome.paid);
    });

    test('закрыл форму — ничего не отправлено', () async {
      final repo = ScriptedRepository(
        onToken: (_) => throw StateError('не должно'),
        onFetch: (_) => throw StateError('не должно'),
      );

      final result = await PaymentFlow(
        repo,
        sdk: FakeSdk(const SdkCanceled()),
      ).run(payment(PaymentStatus.pending));

      expect(result.outcome, PaymentOutcome.dismissed);
      expect(repo.tokens, 0);
    });

    test('банк отказал и банк ещё думает', () async {
      final declined = await PaymentFlow(
        ScriptedRepository(
          onToken: (_) => payment(PaymentStatus.pending, tokenSubmitted: true),
          onFetch: (_) => payment(PaymentStatus.canceled),
        ),
        sdk: FakeSdk(),
      ).run(payment(PaymentStatus.pending));
      expect(declined.outcome, PaymentOutcome.declined);

      final pending = await PaymentFlow(
        ScriptedRepository(
          onToken: (_) => payment(PaymentStatus.pending, tokenSubmitted: true),
          onFetch: (_) => payment(PaymentStatus.pending, tokenSubmitted: true),
        ),
        sdk: FakeSdk(),
        pollDelay: Duration.zero,
        pollAttempts: 3,
      ).run(payment(PaymentStatus.pending));
      expect(pending.outcome, PaymentOutcome.pending);
    });

    test('страница оплаты: открыть и перечитать', () async {
      Uri? opened;
      final result =
          await PaymentFlow(
            ScriptedRepository(
              onToken: (_) => throw StateError('не должно'),
              onFetch: (_) => payment(PaymentStatus.paid),
            ),
            openPage: (url) async => opened = url,
          ).run(
            payment(
              PaymentStatus.pending,
              method: CheckoutMethod.redirect,
              confirmationUrl: 'https://pay.test/5',
            ),
          );

      expect(opened, Uri.parse('https://pay.test/5'));
      expect(result.outcome, PaymentOutcome.paid);
    });

    test('незнакомый способ или провайдер — обновить приложение', () async {
      final repo = ScriptedRepository(
        onToken: (_) => throw StateError('не должно'),
        onFetch: (_) => throw StateError('не должно'),
      );
      final flow = PaymentFlow(repo, sdk: FakeSdk());

      expect(
        (await flow.run(
          payment(PaymentStatus.pending, method: CheckoutMethod.unknown),
        )).outcome,
        PaymentOutcome.needsUpdate,
      );
      expect(
        (await flow.run(
          payment(PaymentStatus.pending, provider: 'other_bank'),
        )).outcome,
        PaymentOutcome.needsUpdate,
      );
    });

    test('сбой сервера на токене — failed, а не исключение', () async {
      final result = await PaymentFlow(
        ScriptedRepository(
          onToken: (_) => throw Exception('502'),
          onFetch: (_) => payment(PaymentStatus.pending),
        ),
        sdk: FakeSdk(),
      ).run(payment(PaymentStatus.pending));
      expect(result.outcome, PaymentOutcome.failed);
    });
  });

  group('размещение осмотра', () {
    late FakeSdk sdk;
    setUp(() {
      sdk = FakeSdk();
      PaymentFlow.sdk = sdk;
    });
    tearDown(() => PaymentFlow.sdk = const YooKassaSdk());

    Future<Order> placed(MockOrderRepository repo) =>
        repo.createInspectionOrder(
          brand: 'Kia',
          model: 'Rio',
          year: 2019,
          city: 'Химки',
          address: 'ул. Ленина, 5',
          inspectOn: DateTime.now().add(const Duration(days: 1)),
          timeSlot: TimeSlot.day,
          askingPrice: 3500,
        );

    OrderStore store(MockOrderRepository repo) => mockStore(
      orders: repo,
    );

    test('без комиссии заказ публикуется сразу', () async {
      final order = await placed(MockOrderRepository());
      expect(order.status, OrderStatus.awaitingExecutor);
      expect(order.pendingPayment, isNull);
    });

    testWidgets('оплата из карточки заказа публикует его', (tester) async {
      final repo = MockOrderRepository()..backend.placementFee = 199;
      final order = await placed(repo);
      expect(order.status, OrderStatus.awaitingPlacement);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: InspectionOrderDetailScreen(
            store: store(repo),
            orderId: order.id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // плашка статуса — капсом, заголовок блока — как есть
      expect(find.text('ЖДЁТ ОПЛАТЫ'), findsOneWidget);
      expect(find.text('ОПЛАТА РАЗМЕЩЕНИЯ'), findsOneWidget);
      await tester.tap(find.text('Оплатить размещение · 199 ₽'));
      await tester.pumpAndSettle();

      expect(sdk.tokenizeCalls, 1);
      expect(find.text('ЖДЁТ ИСПОЛНИТЕЛЯ'), findsOneWidget);
      expect(find.text('Оплатить размещение · 199 ₽'), findsNothing);
      expect(
        (await repo.fetchOrder(order.id)).status,
        OrderStatus.awaitingExecutor,
      );
    });

    testWidgets('закрыл форму — заказ ждёт оплаты дальше', (tester) async {
      sdk.result = const SdkCanceled();
      final repo = MockOrderRepository()..backend.placementFee = 199;
      final order = await placed(repo);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: InspectionOrderDetailScreen(
            store: store(repo),
            orderId: order.id,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Оплатить размещение · 199 ₽'));
      await tester.pumpAndSettle();

      expect(find.text('ЖДЁТ ОПЛАТЫ'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('карточка в «Моих заказах» напоминает об оплате', (
      tester,
    ) async {
      final repo = MockOrderRepository()..backend.placementFee = 199;
      final order = await placed(repo);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: OrderCard(order: order, onTap: () {}),
          ),
        ),
      );

      expect(find.text('Оплатите размещение · 199 ₽'), findsOneWidget);
    });
  });
}
