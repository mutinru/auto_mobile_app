import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:auto_podbor_mobile/data/api_vin_report_repository.dart';
import 'package:auto_podbor_mobile/data/api_review_repository.dart';
import 'package:auto_podbor_mobile/data/api_payment_repository.dart';
import 'package:auto_podbor_mobile/data/api_config_repository.dart';
import 'package:auto_podbor_mobile/data/api_chat_repository.dart';
import 'package:auto_podbor_mobile/data/api_client.dart';
import 'package:auto_podbor_mobile/data/api_inspection_repository.dart';
import 'package:auto_podbor_mobile/data/api_notification_repository.dart';
import 'package:auto_podbor_mobile/data/api_order_repository.dart';
import 'package:auto_podbor_mobile/data/api_verification_repository.dart';
import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/inspection_cache.dart';
import 'package:auto_podbor_mobile/data/legal_repository.dart';
import 'package:auto_podbor_mobile/models/legal_text.dart';
import 'package:auto_podbor_mobile/data/public_feed_repository.dart';
import 'package:auto_podbor_mobile/models/notification_type.dart';
import 'package:auto_podbor_mobile/models/order.dart';
import 'package:auto_podbor_mobile/models/order_action.dart';
import 'package:auto_podbor_mobile/models/order_status.dart';
import 'package:auto_podbor_mobile/models/payment.dart';
import 'package:auto_podbor_mobile/models/vin_kind.dart';

/// Контракт с сервером (ревью №43): настоящие ответы API — снимки, которые
/// пишет ApiContractTest бекенда (tests/Contract/, копия — `make
/// contract-sync`), — разбираются боевым кодом: ApiClient и репозитории.
/// Мок отдаёт снимок только на тот же метод, путь и параметры — уехавший URL
/// тоже ловится.
///
/// Молчаливые потери — провал: пропущенный `parseList` элемент (лог
/// «Пропущен элемент»), список короче, чем в снимке, статус `unknown`.
/// Упал после синхронизации — приложение не разбирает новый ответ: чинить
/// разбор, а не снимок. Руками снимки не правят.
void main() {
  const dir = 'test/fixtures/api';

  /// Снимки, разбор которых проверен ниже. Новый снимок с бекенда без
  /// строки здесь (и проверки разбора) роняет тест «реестр».
  const registry = {
    'me',
    'phone_code_sent',
    'orders_mine_active',
    'orders_mine_finished',
    'orders_assigned_active',
    'orders_available',
    'order_selection_customer',
    'order_selection_executor',
    'order_inspection_report_ready',
    'order_inspection_completed',
    'inspection',
    'defects',
    'order_car_created',
    'library',
    'notifications',
    'support_conversation',
    'support_messages',
    'config',
    'legal_document',
    'vin_report_check',
    'vin_report_purchase',
    'payment',
    'payments',
    'verification',
    'reviews',
    'public_feed',
    'public_order',
  };
  final printed = <String>[];
  late DebugPrintCallback savedPrint;
  late Directory cacheRoot;

  Map<String, dynamic> load(String name) =>
      jsonDecode(File('$dir/$name.json').readAsStringSync())
          as Map<String, dynamic>;

  Map<String, dynamic> body(String name) =>
      load(name)['body'] as Map<String, dynamic>;

  List<dynamic> dataList(String name) => body(name)['data'] as List;

  /// Отдать снимки [names] вместо сети на время [run].
  Future<T> serve<T>(List<String> names, Future<T> Function() run) {
    for (final n in names) {
      expect(registry, contains(n), reason: 'снимок $n не в реестре');
    }
    final snapshots = [for (final n in names) load(n)];
    final client = MockClient((request) async {
      for (final s in snapshots) {
        final recorded = s['request'] as Map<String, dynamic>;
        final target = Uri.parse(recorded['path'] as String);
        if (request.method == recorded['method'] &&
            request.url.path == target.path &&
            mapEquals(
              request.url.queryParametersAll.map(
                (k, v) => MapEntry(k, v.join(',')),
              ),
              target.queryParametersAll.map(
                (k, v) => MapEntry(k, v.join(',')),
              ),
            )) {
          return http.Response.bytes(
            utf8.encode(jsonEncode(s['body'])),
            s['status'] as int,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
      }
      fail('Запрос ${request.method} ${request.url} не из снимков $names');
    });
    return http.runWithClient(run, () => client);
  }

  AuthService signedIn() => AuthService()..debugSetToken('contract');
  ApiClient client() => ApiClient(signedIn());
  ApiOrderRepository orders() => ApiOrderRepository(client());

  void noUnknown(Iterable<Order> list) {
    for (final o in list) {
      expect(o.status, isNot(OrderStatus.unknown), reason: 'заказ #${o.id}');
    }
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    cacheRoot = Directory.systemTemp.createTempSync('contract');
    InspectionCache.debugRoot = cacheRoot;
    InspectionCache.debugReset();
    printed.clear();
    savedPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) printed.add(message);
    };
  });

  tearDown(() {
    debugPrint = savedPrint;
    InspectionCache.debugRoot = null;
    InspectionCache.debugReset();
    cacheRoot.deleteSync(recursive: true);
    final lost = printed.where(
      (m) => m.contains('Пропущен элемент') || m.contains('не пришёл'),
    );
    expect(lost, isEmpty, reason: 'разбор молча потерял данные');
  });

  test('реестр: каждый снимок с бекенда проверен', () {
    final files = Directory(dir)
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last.replaceAll('.json', ''))
        .toSet();
    expect(
      files,
      registry,
      reason: 'новый снимок — добавь проверку его разбора',
    );
  });

  group('профиль и вход', () {
    test('me — текущий пользователь', () async {
      final auth = signedIn();
      await serve(['me'], auth.refreshUser);
      final me = auth.user!;
      expect(me.name, 'Максим К.');
      expect(me.phone, '+79000000001');
      expect(me.payout, isNotNull);
    });

    test('phone_code_sent — код отправлен', () async {
      final sent = await serve(
        ['phone_code_sent'],
        () => AuthService().requestPhoneCode('+79000000009'),
      );
      expect(sent.resendIn, greaterThan(0));
    });
  });

  group('списки заказов', () {
    test('orders_mine_active', () async {
      final list = await serve(['orders_mine_active'], orders().fetchMyOrders);
      expect(list, hasLength(dataList('orders_mine_active').length));
      noUnknown(list);
      final selection = list.firstWhere((o) => !o.isInspection);
      expect(selection.purchaseReport, isNotNull);
      expect(selection.cars.single.verdict, isNotNull);
      final inspection = list.firstWhere(
        (o) => o.status == OrderStatus.reportReady,
      );
      expect(inspection.reportSummary, isNotNull);
    });

    test('orders_mine_finished — страница', () async {
      final page = await serve(
        ['orders_mine_finished'],
        () => orders().fetchMyFinishedOrders(page: 1),
      );
      expect(page.items, hasLength(dataList('orders_mine_finished').length));
      noUnknown(page.items);
      expect(page.items.map((o) => o.status).toSet(), {
        OrderStatus.completed,
        OrderStatus.closed,
        OrderStatus.cancelled,
      });
      expect(page.hasMore, isFalse);
    });

    test('orders_assigned_active — глазами исполнителя', () async {
      final list = await serve(
        ['orders_assigned_active'],
        orders().fetchAssignedOrders,
      );
      expect(list, hasLength(dataList('orders_assigned_active').length));
      noUnknown(list);
    });

    test('orders_available — лента с фасетами', () async {
      final page = await serve(
        ['orders_available'],
        orders().fetchAvailableOrders,
      );
      expect(page.items, hasLength(dataList('orders_available').length));
      noUnknown(page.items);
      expect(page.cityFacets, isNotEmpty);
      expect(page.brandFacets, isNotEmpty);
      expect(page.all, page.items.length);
    });
  });

  group('заказ', () {
    int id(String name) => (body(name)['data'] as Map)['id'] as int;

    test('order_selection_customer — подбор у заказчика', () async {
      final order = await serve(
        ['order_selection_customer'],
        () => orders().fetchOrder(id('order_selection_customer')),
      );
      expect(order.viewerRole, ViewerRole.customer);
      expect(order.counterpartPhone, '+79000000001');
      final car = order.cars.single;
      expect(car.verdict, isNotNull);
      expect(order.purchaseReport?.carId, car.id);
      expect(order.can(OrderAction.declinePurchaseReport), isTrue);
    });

    test('order_selection_executor — тот же подбор у исполнителя', () async {
      final order = await serve(
        ['order_selection_executor'],
        () => orders().fetchOrder(id('order_selection_executor')),
      );
      expect(order.viewerRole, ViewerRole.executor);
      expect(order.cars.single.sellerPhone, '+79161234567');
      expect(order.can(OrderAction.release), isTrue);
      expect(order.can(OrderAction.addCandidate), isTrue);
    });

    test('order_inspection_report_ready — до оплаты без вердикта', () async {
      final order = await serve(
        ['order_inspection_report_ready'],
        () => orders().fetchOrder(id('order_inspection_report_ready')),
      );
      expect(order.status, OrderStatus.reportReady);
      expect(order.reportSummary?.panelsTotal, greaterThan(0));
      expect(order.cars.single.verdict, isNull);
      expect(order.payout, isNotNull);
    });

    test('order_inspection_completed — после оплаты с вердиктом', () async {
      final order = await serve(
        ['order_inspection_completed'],
        () => orders().fetchOrder(id('order_inspection_completed')),
      );
      expect(order.status, OrderStatus.completed);
      expect(order.cars.single.verdict, isNotNull);
    });
  });

  group('осмотр', () {
    test('inspection — детали, фото, дефект', () async {
      final data = body('inspection')['data'] as Map<String, dynamic>;
      final snapshot = await serve(
        ['inspection'],
        () => ApiInspectionRepository(
          client(),
          inspectionId: data['id'] as int,
        ).fetchInspection(),
      );
      expect(snapshot.panels, hasLength((data['panels'] as List).length));
      final photo = snapshot.panels.expand((p) => p.photos).single;
      expect(photo.url, isNotNull);
      expect(photo.thumbUrl, isNotNull);
      expect(snapshot.panels.expand((p) => p.defects), isNotEmpty);
      expect(snapshot.offline, isFalse);
    });

    test('defects — каталог', () async {
      final catalog = await serve(
        ['defects'],
        () => ApiInspectionRepository(
          client(),
          inspectionId: 1,
        ).fetchDefectCatalog(),
      );
      expect(catalog, hasLength(dataList('defects').length));
    });

    test('order_car_created — кандидат приходит с осмотром', () async {
      final photos = Directory.systemTemp.createTempSync('photos');
      addTearDown(() => photos.deleteSync(recursive: true));
      final vin = File('${photos.path}/vin.jpg')..writeAsBytesSync([0xFF]);
      final odometer = File('${photos.path}/odo.jpg')..writeAsBytesSync([0xFF]);
      final path = (load('order_car_created')['request'] as Map)['path'];
      final orderId = int.parse(RegExp(r'orders/(\d+)').firstMatch(path)![1]!);

      final car = await serve(
        ['order_car_created'],
        () => orders().addCar(
          orderId,
          brand: 'Kia',
          model: 'Rio',
          year: 2019,
          vin: CapturedVin(
            value: 'XW8ZZZ61ZKG000001',
            kind: VinKind.vin,
            photoPath: vin.path,
          ),
          odometer: CapturedOdometer(km: 127450, photoPath: odometer.path),
        ),
      );
      expect(car.inspectionId, isNotNull);
      expect(car.sellerPhone, '+79161234567');
      // снимки таблички и одометра — подписанные ссылки
      expect(car.vinPhotoUrl, isNotNull);
      expect(car.odometerPhotoUrl, isNotNull);
    });

    test('library — библиотека осмотров', () async {
      final path = (load('library')['request'] as Map)['path'] as String;
      final orderId = int.parse(RegExp(r'orders/(\d+)').firstMatch(path)![1]!);
      final page = await serve(
        ['library'],
        () => orders().fetchInspectionLibrary(orderId),
      );
      expect(page.items, hasLength(dataList('library').length));
      expect(page.days, greaterThan(0));
    });
  });

  group('уведомления и чат', () {
    test('notifications — лента', () async {
      final page = await serve(
        ['notifications'],
        () => ApiNotificationRepository(client()).fetchPage(),
      );
      expect(page.items, hasLength(dataList('notifications').length));
      for (final n in page.items) {
        expect(n.type, isNot(NotificationType.unknown));
      }
    });

    test('support_conversation и support_messages — чат поддержки', () async {
      final chat = ApiChatRepository(client());
      final messages = await serve([
        'support_conversation',
        'support_messages',
      ], () async => chat.fetchMessages((await chat.openSupport()).id));
      expect(messages, hasLength(dataList('support_messages').length));
    });
  });

  group('оплата и настройки', () {
    test('legal_document — документ блоками, гостем', () async {
      final text = await serve(
        [
          'legal_document',
        ],
        () => ApiLegalRepository(
          ApiClient(AuthService()),
        ).fetch(LegalDocument.terms),
      );
      expect(text.title, isNotEmpty);
      expect(text.edition, isNotNull);

      // ни один блок не потерян: обход в глубину по ответу и по разбору
      int rawCount(Object? blocks) {
        var n = 0;
        for (final b in blocks as List? ?? const []) {
          n += 1 + rawCount((b as Map)['children']);
          for (final item in b['items'] as List? ?? const []) {
            n += rawCount(item);
          }
        }
        return n;
      }

      int parsedCount(List<LegalBlock> blocks) {
        var n = 0;
        for (final b in blocks) {
          n += 1 + parsedCount(b.children);
          for (final item in b.items) {
            n += parsedCount(item);
          }
        }
        return n;
      }

      final raw = body('legal_document')['data']['blocks'];
      expect(parsedCount(text.blocks), rawCount(raw));

      // фикстура бекенда — каждый вид блока, который рисует приложение
      final types = <LegalBlockType>{};
      void walk(List<LegalBlock> blocks) {
        for (final b in blocks) {
          types.add(b.type);
          walk(b.children);
          b.items.forEach(walk);
        }
      }

      walk(text.blocks);
      expect(types, LegalBlockType.values.toSet());
      final spans = text.blocks.expand((b) => b.spans);
      expect(spans.any((s) => s.strong), isTrue);
      expect(spans.any((s) => s.em), isTrue);
      expect(spans.any((s) => s.code), isTrue);
      expect(
        spans
            .map((s) => s.link)
            .whereType<String>()
            .map(LegalDocument.fromLink),
        contains(isNotNull),
      );
    });

    test('config', () async {
      final config = await serve([
        'config',
      ], ApiConfigRepository(client()).fetchClientConfig);
      expect(config.inspectionPlacementFee, isNotNull);
    });

    test('vin_report_check, vin_report_purchase, payment', () async {
      const vin = 'XW8ZZZ61ZKG100111';
      final reports = ApiVinReportRepository(client());
      final check = await serve([
        'vin_report_check',
      ], () => reports.checkVinReports(vin));
      expect(check.items, isNotEmpty);

      final purchase = await serve([
        'vin_report_purchase',
      ], () => reports.purchaseVinReport(vin));
      final paymentId = purchase.payment!.id;

      final payment = await serve([
        'payment',
      ], () => ApiPaymentRepository(client()).fetchPayment(paymentId));
      expect(payment.status, isNot(PaymentStatus.unknown));
      expect(payment.checkout?.method, CheckoutMethod.sdk);
    });

    test('payments — платежи с чеками', () async {
      final page = await serve([
        'payments',
      ], () => ApiPaymentRepository(client()).fetchPayments());
      expect(page.items, hasLength(dataList('payments').length));
      final receipt = page.items.first.receipt;
      expect(receipt?.status, ReceiptStatus.registered);
      expect(receipt?.url, isNotNull);
    });

    test('verification', () async {
      final summary = await serve(
        ['verification'],
        () => ApiVerificationRepository(client()).fetchSummary(),
      );
      expect(summary.total, greaterThan(0));
    });

    test('reviews — отзывы исполнителя', () async {
      final path = (load('reviews')['request'] as Map)['path'] as String;
      final userId = int.parse(RegExp(r'users/(\d+)').firstMatch(path)![1]!);
      final page = await serve(
        ['reviews'],
        () => ApiReviewRepository(client()).fetchExecutorReviews(userId),
      );
      expect(page.items, hasLength(dataList('reviews').length));
    });
  });

  group('витрина', () {
    test('public_feed и public_order', () async {
      final repo = PublicFeedRepository();
      final (stats, cards) = await serve(['public_feed'], repo.fetchFeed);
      expect(cards, hasLength(dataList('public_feed').length));
      expect(stats.completed, isNotNull);

      final id = (body('public_order')['data'] as Map)['id'] as int;
      final order = await serve(['public_order'], () => repo.fetchOrder(id));
      expect(order.id, id);
    });
  });
}
