import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/api_exception.dart';
import 'package:auto_podbor_mobile/data/address_repository.dart';
import 'package:auto_podbor_mobile/data/mock_inspection_repository.dart';
import 'package:auto_podbor_mobile/models/inspection_verdict.dart';
import 'package:auto_podbor_mobile/models/payment.dart';
import 'package:auto_podbor_mobile/models/vin_report.dart';
import 'package:auto_podbor_mobile/payments/payment_flow.dart';
import 'package:auto_podbor_mobile/payments/payment_sdk.dart';
import 'package:auto_podbor_mobile/screens/inspection_report_screen.dart';
import 'package:auto_podbor_mobile/screens/new_inspection_screen.dart';
import 'package:auto_podbor_mobile/screens/vin_report_screen.dart';
import 'package:auto_podbor_mobile/state/inspection_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/data/mock_backend.dart';
import 'package:auto_podbor_mobile/data/mock_fixtures.dart';
import 'package:auto_podbor_mobile/data/mock_vin_report_repository.dart';

import 'support/stores.dart';

/// Проверка VIN по команде теста — чтобы поймать устаревший ответ.
class _SlowCheck extends MockVinReportRepository {
  _SlowCheck() : super(MockBackend());

  final pending = <String, Completer<VinReportCheck>>{};

  @override
  Future<VinReportCheck> checkVinReports(String vin) =>
      (pending[vin] = Completer()).future;
}

class _LimitReached extends MockVinReportRepository {
  _LimitReached() : super(MockBackend());

  @override
  Future<VinReportCheck> checkVinReports(String vin) async =>
      throw ApiException(
        429,
        '{"message":"Можно проверить 15 VIN в сутки — попробуйте завтра"}',
      );
}

const _vin = MockFixtures.reportVin;

/// Отчёты по VIN над своим миром мока.
MockVinReportRepository _reports() => MockVinReportRepository(MockBackend());

/// Форма SDK без плагина.
class _Sdk implements PaymentSdk {
  _Sdk(this.result);

  final SdkTokenResult result;
  int calls = 0;

  @override
  Future<SdkTokenResult> tokenize(Payment payment) async {
    calls++;
    return result;
  }

  @override
  Future<void> confirm(
    Payment payment, {
    required String url,
    required String methodType,
  }) async {}
}

/// Готовые отчёты по VIN в форме разового осмотра и купленные пакеты.
void main() {
  Future<void> open(
    WidgetTester tester,
    MockVinReportRepository reports,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: NewInspectionScreen(
          store: mockStore(
            backend: reports.backend,
            vinReports: reports,
            addresses: MockAddressRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder vinField() => find.widgetWithText(TextField, '17 символов');

  Future<void> typeVin(WidgetTester tester, String vin) async {
    await tester.enterText(vinField(), vin);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  testWidgets('подсказка у поля, отчётов нет — предложения нет', (
    tester,
  ) async {
    await open(tester, _reports());

    expect(find.textContaining('проверим, нет ли готового'), findsOneWidget);
    await typeVin(tester, 'Z94CB41AAGR123456');
    expect(find.textContaining('уже осматривали'), findsNothing);
  });

  testWidgets('VIN с отчётами — тизер и цена, без вердикта', (tester) async {
    await open(tester, _reports());
    await typeVin(tester, _vin.toLowerCase());

    expect(find.text('Эту машину уже осматривали 2 раза'), findsOneWidget);
    expect(
      find.text('Последний — 20 октября · Москва · 112 000 км'),
      findsOneWidget,
    );
    expect(find.text('Купить за 299 ₽'), findsOneWidget);
    expect(find.text('С оговорками'), findsNothing);
  });

  testWidgets('номер кузова не проверяется — поле только для VIN', (
    tester,
  ) async {
    final repo = _SlowCheck();
    await open(tester, repo);
    await tester.enterText(vinField(), 'gx110-6012345');
    await tester.pump(const Duration(milliseconds: 600));

    // дефис отсекается форматтером VIN, запроса проверки нет
    expect(
      find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == 'GX1106012345',
      ),
      findsOneWidget,
    );
    expect(repo.pending, isEmpty);
  });

  testWidgets('ответ на прежний VIN не показывается', (tester) async {
    final repo = _SlowCheck();
    await open(tester, repo);
    await tester.enterText(vinField(), _vin);
    await tester.pump(const Duration(milliseconds: 600));

    // заказчик исправил VIN, пока шла проверка прежнего
    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == _vin,
      ),
      'Z94CB41AAGR123456',
    );
    repo.pending[_vin]!.complete(
      await _reports().checkVinReports(_vin),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('уже осматривали'), findsNothing);
  });

  testWidgets('лимит проверок — строкой под полем', (tester) async {
    await open(tester, _LimitReached());
    await typeVin(tester, _vin);

    expect(
      find.text('Можно проверить 15 VIN в сутки — попробуйте завтра'),
      findsOneWidget,
    );
  });

  testWidgets('покупка открывает пакет с вердиктами, затем «Открыть»', (
    tester,
  ) async {
    final repo = _reports();
    await open(tester, repo);
    await typeVin(tester, _vin);

    await tester.tap(find.text('Купить за 299 ₽'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('голосовых заметок в отчёте нет'),
      findsOneWidget,
    );
    await tester.tap(find.text('Оплатить 299 ₽'));
    await tester.pumpAndSettle();

    expect(find.text('Volkswagen Tiguan 2019'), findsOneWidget);
    expect(find.text('С оговорками'), findsOneWidget);
    expect(find.text('Перекрашено крыло'), findsOneWidget);
    expect(find.text('Можно брать'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.text('Открыть отчёт'), findsOneWidget);
  });

  testWidgets('с провайдером покупка проходит формой SDK, потом отчёт', (
    tester,
  ) async {
    final sdk = _Sdk(const SdkToken('tok', 'sbp'));
    PaymentFlow.sdk = sdk;
    addTearDown(() => PaymentFlow.sdk = const YooKassaSdk());
    final repo = _reports()..backend.vinReportPaidInstantly = false;
    await open(tester, repo);
    await typeVin(tester, _vin);

    await tester.tap(find.text('Купить за 299 ₽'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Оплатить 299 ₽'));
    await tester.pumpAndSettle();

    expect(sdk.calls, 1);
    // вердикты — только из перечитанной после оплаты покупки
    expect(find.text('Перекрашено крыло'), findsOneWidget);
  });

  testWidgets('закрыл форму оплаты — отчёт не открывается', (tester) async {
    PaymentFlow.sdk = _Sdk(const SdkCanceled());
    addTearDown(() => PaymentFlow.sdk = const YooKassaSdk());
    final repo = _reports()..backend.vinReportPaidInstantly = false;
    await open(tester, repo);
    await typeVin(tester, _vin);

    await tester.tap(find.text('Купить за 299 ₽'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Оплатить 299 ₽'));
    await tester.pumpAndSettle();

    expect(find.text('Перекрашено крыло'), findsNothing);
    expect(await repo.fetchVinReportPurchases(), isEmpty);
  });

  testWidgets('купленные отчёты: пусто, затем пакет', (tester) async {
    final repo = _reports();
    Widget list() => MaterialApp(
      theme: AppTheme.dark,
      home: VinReportsScreen(repository: repo),
    );

    await tester.pumpWidget(list());
    await tester.pumpAndSettle();
    expect(find.textContaining('Пока пусто'), findsOneWidget);

    await repo.purchaseVinReport(_vin);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(list());
    await tester.pumpAndSettle();
    expect(find.text('Volkswagen Tiguan 2019'), findsOneWidget);
    expect(find.text('VIN ··· 100111 · 2 осмотра'), findsOneWidget);
  });

  testWidgets('отчёт из пакета: вердикт покупки, без заказа', (tester) async {
    final store = InspectionStore(MockInspectionRepository(), readOnly: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: InspectionReportScreen.purchased(
          store: store,
          title: 'Volkswagen Tiguan 2019',
          verdict: InspectionVerdict.notRecommended,
          verdictComment: 'Крыло после ДТП',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Отчёт'), findsOneWidget);
    expect(find.text('Не рекомендую'), findsOneWidget);
    expect(find.text('Крыло после ДТП'), findsOneWidget);
  });
}
