import 'package:flutter/foundation.dart';
import '../models/available_page.dart';
import '../models/inspection_outcome.dart';
import '../models/inspection_verdict.dart';
import '../models/library_inspection.dart';
import '../models/nearby_filter.dart';
import '../models/order.dart';
import '../models/order_action.dart';
import '../models/order_car.dart';
import '../models/order_page.dart';
import '../models/order_kind.dart';
import '../models/order_response.dart';
import '../models/order_response_status.dart';
import '../models/order_status.dart';
import '../models/payout.dart';
import '../models/report_summary.dart';
import '../models/review.dart';
import '../models/vin_kind.dart';
import 'api_exception.dart';
import '../models/time_slot.dart';
import '../models/user_summary.dart';
import '../util/listing_url.dart';
import 'mock_backend.dart';
import 'mock_fixtures.dart';
import 'order_repository.dart';

/// Заказы для виджет-тестов без бекенда (ревью №39): поведение сервера
/// над общим миром [MockBackend]. Фикстура заказов — [MockFixtures.orders]
/// (правка двигает вёрстку соседних suites — прогоняй flutter test целиком).
class MockOrderRepository implements OrderRepository {
  /// [orders] — свой набор вместо общей фикстуры: тестам оплаты нужны
  /// заказы в reportReady/paymentSent, а правка [_seed] двигает вёрстку
  /// соседних suites.
  /// [availablePageSize] — страница ленты «Заказы рядом»; маленькая —
  /// чтобы проверить подгрузку на двух заказах фикстуры.
  MockOrderRepository({
    List<Order>? orders,
    this.availablePageSize = 20,
    MockBackend? backend,
  }) : backend = backend ?? MockBackend(orders: orders);

  /// Общий мир мока: заказы, платежи, покупки по VIN. Остальные моки
  /// (`MockPaymentRepository` и др.) работают над ним же — оплата
  /// размещения публикует заказ, как на сервере.
  final MockBackend backend;

  List<Order> get _orders => backend.orders;

  final int availablePageSize;

  /// Страница завершённых — как на сервере (App\Queries\OrderLists::PAGE).
  static const finishedPageSize = 20;

  /// Как сервер: активные — целиком, завершённые — отдельно страницами.
  @override
  Future<List<Order>> fetchMyOrders() async =>
      _orders.where((o) => !o.status.isFinished).toList();

  @override
  Future<OrderPage> fetchMyFinishedOrders({int page = 1}) async =>
      _finishedPage(_orders.where((o) => o.status.isFinished), page);

  /// Страница завершённых от последнего закрытого, без метки — по номеру.
  OrderPage _finishedPage(Iterable<Order> finished, int page) {
    final sorted = finished.toList()
      ..sort((a, b) {
        final (ca, cb) = (a.closedAt, b.closedAt);
        if (ca != null && cb != null && ca != cb) return cb.compareTo(ca);
        if (ca != null && cb == null) return -1;
        if (ca == null && cb != null) return 1;
        return b.id.compareTo(a.id);
      });
    final start = (page - 1) * finishedPageSize;
    return OrderPage(
      items: sorted.skip(start).take(finishedPageSize).toList(),
      hasMore: sorted.length > start + finishedPageSize,
    );
  }

  /// Как сервер: фильтр той же логикой ([applyNearbyFilter]), страницы и
  /// варианты шторки — по всем свободным.
  @override
  Future<AvailablePage> fetchAvailableOrders({
    NearbyFilter filter = const NearbyFilter(),
    bool fewResponses = false,
    int page = 1,
  }) async {
    final open = _open();
    final filtered = _filtered(open, filter, fewResponses);
    final from = (page - 1) * availablePageSize;
    final items = filtered.skip(from).take(availablePageSize).toList();
    List<Facet> facets(Iterable<String> values) {
      final counts = <String, int>{};
      for (final v in values) {
        counts[v] = (counts[v] ?? 0) + 1;
      }
      return [
        for (final name in counts.keys.toList()..sort())
          Facet(name, counts[name]!),
      ];
    }

    return AvailablePage(
      items: items,
      page: page,
      hasMore: from + items.length < filtered.length,
      total: filtered.length,
      all: open.length,
      cityFacets: page == 1
          ? facets(open.expand((o) => o.cities.toSet()))
          : null,
      brandFacets: page == 1 ? facets(open.map((o) => o.brand)) : null,
    );
  }

  @override
  Future<int> countAvailableOrders({
    NearbyFilter filter = const NearbyFilter(),
    bool fewResponses = false,
  }) async => _filtered(_open(), filter, fewResponses).length;

  List<Order> _open() => _orders
      .where((o) => o.status == OrderStatus.awaitingExecutor)
      .map(_asExecutor)
      .toList();

  static List<Order> _filtered(
    List<Order> open,
    NearbyFilter filter,
    bool fewResponses,
  ) => applyNearbyFilter(
    open,
    filter,
  ).where((o) => !fewResponses || o.responsesCount <= 2).toList();

  /// Как бекенд (OrderResource): не заказчику — только свой отклик,
  /// в responsesCount — отклики в игре, без устаревших после переноса.
  static Order _asExecutor(Order o) => o.copyWith(
    responses: o.responses
        .where((r) => r.executor.id == MockFixtures.me.id)
        .toList(),
    responsesCount: o.responses.where((r) => r.status.isActive).length,
  );

  @override
  Future<List<Order>> fetchAssignedOrders() async => _orders
      .where(
        (o) =>
            o.executor != null &&
            (!o.status.isFinished || o.hasUnfinishedInspection),
      )
      .toList();

  @override
  Future<OrderPage> fetchAssignedFinishedOrders({int page = 1}) async =>
      _finishedPage(
        _orders.where(
          (o) =>
              o.executor != null &&
              o.status.isFinished &&
              !o.hasUnfinishedInspection,
        ),
        page,
      );

  @override
  Future<Order> fetchOrder(int id) async =>
      withActions(_orders.firstWhere((o) => o.id == id));

  /// Действия, которые мок помнит сам (отзыв оставлен, окно спора,
  /// «сообщить о покупке» после «нет»): остальные выводятся из статуса.
  static const _stateful = {
    OrderAction.review,
    OrderAction.dispute,
    OrderAction.reportPurchase,
  };

  /// Имитация сервера (`App\Orders\OrderActions`): карта действий по тем
  /// же правилам. Экраны правила не повторяют — только читают карту. Кто
  /// смотрит, мок не знает: действия исполнителя есть, если он назначен, —
  /// показывает их только экран исполнителя.
  @visibleForTesting
  static Order withActions(Order o) {
    final mine = o.customer.id == MockFixtures.me.id;
    final hasExecutor = o.executor != null;
    final selection = !o.isInspection;
    final open =
        selection &&
        (o.status == OrderStatus.sourcing ||
            o.status == OrderStatus.inspecting);
    final inspected = o.cars.where((c) => c.inspectionId != null).toList();
    final derived = {
      if (mine &&
          o.status == OrderStatus.awaitingExecutor &&
          o.responses.any((r) => r.status == OrderResponseStatus.pending))
        OrderAction.acceptResponse,
      if (mine &&
          (o.status == OrderStatus.awaitingPlacement ||
              o.status == OrderStatus.awaitingExecutor ||
              o.status == OrderStatus.awaitingDecision))
        OrderAction.cancel,
      if (mine && o.status == OrderStatus.awaitingDecision) OrderAction.repost,
      if (mine && o.status == OrderStatus.awaitingPlacement)
        OrderAction.payPlacement,
      if (mine && open && inspected.isNotEmpty) OrderAction.complete,
      if (mine && o.purchaseReport != null) OrderAction.declinePurchaseReport,
      if (mine && o.purchaseEditableUntil != null && inspected.length > 1)
        OrderAction.changePurchase,
      if (mine && o.status == OrderStatus.reportReady) OrderAction.markPaid,
      if (hasExecutor && open) OrderAction.addCandidate,
      if (hasExecutor && selection && o.status != OrderStatus.cancelled)
        OrderAction.editSellerPhone,
      if (hasExecutor &&
          (o.isInspection
              ? o.status == OrderStatus.scheduled ||
                    o.status == OrderStatus.inspecting
              : open))
        OrderAction.release,
      if (hasExecutor &&
          o.isInspection &&
          o.status == OrderStatus.scheduled &&
          o.cars.isNotEmpty)
        OrderAction.startInspection,
      if (hasExecutor && o.isInspection && o.status == OrderStatus.inspecting)
        OrderAction.finishInspection,
      if (hasExecutor && o.status == OrderStatus.paymentSent)
        OrderAction.confirmPayment,
    };
    return o.copyWith(
      actions: {...o.actions.intersection(_stateful), ...derived},
    );
  }

  /// [actions] с [action] включённым или выключенным.
  static Set<OrderAction> _set(
    Set<OrderAction> actions,
    OrderAction action,
    bool on,
  ) => on ? {...actions, action} : actions.difference({action});

  @override
  Future<Order> createOrder({
    required String brand,
    required String model,
    int? yearFrom,
    int? mileageTo,
    int? budgetMin,
    int? budgetMax,
    List<String> cities = const [],
    List<String> requirements = const [],
    String? comment,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final fee = backend.selectionPlacementFee;
    final order = Order(
      id: id,
      status: fee > 0
          ? OrderStatus.awaitingPlacement
          : OrderStatus.awaitingExecutor,
      placementFee: fee > 0 ? fee : null,
      pendingPayment: fee > 0
          ? backend.startPayment(fee, 'selection_placement', orderId: id)
          : null,
      brand: brand,
      model: model,
      yearFrom: yearFrom,
      mileageTo: mileageTo,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      cities: cities,
      requirements: requirements,
      comment: comment,
      customer: MockFixtures.me,
    );
    _orders.insert(0, order);
    return order;
  }

  @override
  Future<Order> createInspectionOrder({
    required String brand,
    required String model,
    required int year,
    int? mileageKm,
    required String city,
    required String address,
    required DateTime inspectOn,
    required TimeSlot timeSlot,
    required int askingPrice,
    String? inspectTime,
    String? vin,
    String? listingUrl,
    String? sellerPhone,
    String? comment,
    String? cityId,
    double? lat,
    double? lon,
    int? addressPrecision,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final fee = backend.placementFee;
    final order = Order(
      id: id,
      kind: OrderKind.inspection,
      status: fee > 0
          ? OrderStatus.awaitingPlacement
          : OrderStatus.awaitingExecutor,
      placementFee: fee > 0 ? fee : null,
      pendingPayment: fee > 0
          ? backend.startPayment(fee, 'inspection_placement', orderId: id)
          : null,
      brand: brand,
      model: model,
      yearFrom: year,
      mileageTo: mileageKm,
      customer: MockFixtures.me,
      cities: [city],
      address: address,
      lat: lat,
      lon: lon,
      inspectOn: inspectOn,
      timeSlot: timeSlot,
      inspectTime: timeSlot == TimeSlot.exact ? inspectTime : null,
      askingPrice: askingPrice,
      // как сервер: нормализует ссылку и подписывает площадку
      listingUrl: listingUrl == null ? null : normalizeListingUrl(listingUrl),
      listingHost: listingUrl == null ? null : listingHost(listingUrl),
      listingSite: listingUrl == null ? null : listingSite(listingUrl),
      hasListing: listingUrl != null && listingUrl.isNotEmpty,
      sellerPhone: sellerPhone,
      comment: comment,
      cars: [
        OrderCar(
          id: id + 1,
          brand: brand,
          model: model,
          year: year,
          vinMasked: vin == null || vin.isEmpty
              ? '\u2014'
              : '\u00b7\u00b7\u00b7 ${vin.substring(vin.length - 6)}',
          // как сервер: пробег заказчика — со слов продавца, не одометр
          customerMileageKm: mileageKm,
        ),
      ],
    );
    _orders.insert(0, order);
    return order;
  }

  @override
  Future<Order> completeInspection(
    int orderId, {
    required InspectionVerdict verdict,
    String? comment,
  }) async {
    final order = await fetchOrder(orderId);
    final car = order.cars.first;
    // как на бекенде: заказ не закрывается, отчёт ждёт оплаты
    final updated = order.copyWith(
      status: OrderStatus.reportReady,
      payout: MockFixtures.payout,
      reportSummary: const ReportSummary(
        panelsTotal: 17,
        panelsInspected: 17,
        defectsCount: 2,
        photosCount: 5,
      ),
      cars: [
        OrderCar(
          id: car.id,
          brand: car.brand,
          model: car.model,
          year: car.year,
          vinMasked: car.vinMasked,
          mileageKm: car.mileageKm,
          customerMileageKm: car.customerMileageKm,
          mileageMismatch: car.mileageMismatch,
          odometerPhotoUrl: car.odometerPhotoUrl,
          odometerPhotoThumbUrl: car.odometerPhotoThumbUrl,
          inspectionId: car.inspectionId,
          inspectionStatus: 'completed',
          verdict: verdict,
          verdictComment: comment,
        ),
      ],
    );
    return _replace(updated);
  }

  @override
  Future<Order> respondToOrder(
    int orderId, {
    required int proposedPrice,
    String? message,
    Payout? payout,
  }) async {
    final order = await fetchOrder(orderId);
    // как Order::addResponse(): устаревший после переноса отклик оживает
    final mine = order.responses.where(
      (r) => r.executor.id == MockFixtures.me.id,
    );
    final updated = order.copyWith(
      responses: [
        for (final r in order.responses)
          if (r.executor.id != MockFixtures.me.id) r,
        OrderResponse(
          id: mine.isEmpty ? order.responses.length + 1 : mine.first.id,
          status: OrderResponseStatus.pending,
          proposedPrice: proposedPrice,
          message: message,
          executor: MockFixtures.me,
        ),
      ],
    );
    _replace(updated);
    return _asExecutor(updated);
  }

  @override
  Future<Order> completeCandidate(
    int orderId,
    int carId, {
    required InspectionVerdict verdict,
    String? comment,
  }) async {
    final order = await fetchOrder(orderId);
    // как Order::finishCandidateInspection(): статус заказа прежний
    final updated = order.copyWith(
      cars: [
        for (final c in order.cars)
          c.id != carId
              ? c
              : OrderCar(
                  id: c.id,
                  brand: c.brand,
                  model: c.model,
                  year: c.year,
                  vinMasked: c.vinMasked,
                  mileageKm: c.mileageKm,
                  inspectionId: c.inspectionId,
                  inspectionStatus: 'completed',
                  inspectionOutcome: c.inspectionOutcome,
                  verdict: verdict,
                  verdictComment: comment,
                ),
      ],
    );
    return _replace(updated);
  }

  @override
  Future<Order> completeSelection(int orderId, {required int carId}) async {
    final order = await fetchOrder(orderId);
    final now = DateTime.now();
    final updated = order.copyWith(
      status: OrderStatus.completed,
      completedAt: now,
      actions: _set(
        _set(order.actions, OrderAction.review, order.executor != null),
        OrderAction.reportPurchase,
        false,
      ),
      cars: _withPurchase(order.cars, carId),
      clearPurchaseReport: true,
      purchaseEditableUntil: now.add(const Duration(hours: 24)),
    );
    return _replace(updated);
  }

  /// Как Order::applyPurchase(): исход только у кандидатов с осмотром.
  List<OrderCar> _withPurchase(List<OrderCar> cars, int carId) => [
    for (final c in cars)
      c.inspectionId == null
          ? c
          : c.withOutcome(
              c.id == carId
                  ? InspectionOutcome.purchased
                  : InspectionOutcome.rejected,
            ),
  ];

  /// Последний вызов [reportPurchase] — для тестов.
  int? lastReportedCarId;

  @override
  Future<Order> reportPurchase(int orderId, {required int carId}) async {
    lastReportedCarId = carId;
    final order = await fetchOrder(orderId);
    final updated = order.copyWith(
      purchaseReport: PurchaseReport(carId: carId, reportedAt: DateTime.now()),
      actions: _set(order.actions, OrderAction.reportPurchase, false),
    );
    return _replace(updated);
  }

  @override
  Future<Order> declinePurchaseReport(int orderId) async {
    final order = await fetchOrder(orderId);
    // после «нет» сервер сутки не даёт сообщить снова
    final updated = order.copyWith(
      clearPurchaseReport: true,
      actions: _set(order.actions, OrderAction.reportPurchase, false),
    );
    return _replace(updated);
  }

  @override
  Future<Order> changePurchase(int orderId, {required int carId}) async {
    final order = await fetchOrder(orderId);
    final updated = order.copyWith(cars: _withPurchase(order.cars, carId));
    return _replace(updated);
  }

  @override
  Future<Order> repostSelection(int orderId) async {
    final order = await fetchOrder(orderId);
    if (order.status != OrderStatus.awaitingDecision) {
      throw ApiException(422, '{"message":"Заказ не ждёт решения"}');
    }
    return _replace(
      order.copyWith(
        status: OrderStatus.awaitingExecutor,
        clearDecision: true,
        pickUntil: DateTime.now().add(const Duration(days: 5)),
      ),
    );
  }

  @override
  Future<Order> repostInspection(
    int orderId, {
    required DateTime inspectOn,
    required TimeSlot timeSlot,
    String? inspectTime,
    int? askingPrice,
  }) async {
    final order = await fetchOrder(orderId);
    final updated = order.copyWith(
      status: OrderStatus.awaitingExecutor,
      inspectOn: inspectOn,
      timeSlot: timeSlot,
      inspectTime: timeSlot == TimeSlot.exact ? inspectTime : null,
      askingPrice: askingPrice,
      clearDecision: true,
      // как Order::repost(): прежние отклики были под старую дату —
      // ждавшие выбора и отказавшиеся могут откликнуться снова
      responses: [
        for (final r in order.responses)
          r.status == OrderResponseStatus.pending ||
                  r.status == OrderResponseStatus.declined
              ? OrderResponse(
                  id: r.id,
                  status: OrderResponseStatus.outdated,
                  proposedPrice: r.proposedPrice,
                  message: r.message,
                  executor: r.executor,
                )
              : r,
      ],
    );
    return _replace(updated);
  }

  @override
  Future<Order> cancelOrder(int orderId) async {
    final order = await fetchOrder(orderId);
    final updated = order.copyWith(
      status: OrderStatus.cancelled,
      // как Order::cancel(): ожидающие отклики отклоняются
      responses: [
        for (final r in order.responses)
          r.status == OrderResponseStatus.pending
              ? OrderResponse(
                  id: r.id,
                  status: OrderResponseStatus.rejected,
                  proposedPrice: r.proposedPrice,
                  message: r.message,
                  executor: r.executor,
                )
              : r,
      ],
    );
    return _replace(updated);
  }

  @override
  Future<Order> acceptResponse(int orderId, int responseId) async {
    final order = await fetchOrder(orderId);
    final response = order.responses.firstWhere((r) => r.id == responseId);
    final updated = order.copyWith(
      // у осмотра принятый отклик означает «назначен», у подбора — «идёт подбор»
      status: order.isInspection ? OrderStatus.scheduled : OrderStatus.sourcing,
      price: response.proposedPrice,
      executor: response.executor,
      // как Order::counterpartPhoneFor: у подбора номера открываются сторонам
      counterpartPhone: order.isInspection ? null : '+79000000010',
      executorDeadlineAt: order.isInspection
          ? DateTime.now().add(const Duration(hours: 24))
          : null,
      // как на бекенде (Order::acceptResponse): у подбора остальные отклики
      // отклоняются, у осмотра остаются ждать — на случай отказа исполнителя
      responses: [
        for (final r in order.responses)
          OrderResponse(
            id: r.id,
            status: r.id == responseId
                ? OrderResponseStatus.accepted
                : order.isInspection
                ? r.status
                : OrderResponseStatus.rejected,
            proposedPrice: r.proposedPrice,
            message: r.message,
            executor: r.executor,
          ),
      ],
    );
    return _replace(updated);
  }

  @override
  Future<OrderCar> addCar(
    int orderId, {
    required String brand,
    required String model,
    required int year,
    required CapturedVin vin,
    required CapturedOdometer odometer,
    String? licensePlate,
    String? sellerPhone,
  }) async {
    lastVin = vin;
    lastSellerPhone = sellerPhone;
    lastOdometer = odometer;
    final v = vin.value;
    final id = DateTime.now().millisecondsSinceEpoch;
    // как сервер: кандидат приходит уже с начатым осмотром
    return OrderCar(
      id: id,
      brand: brand,
      model: model,
      year: year,
      vinMasked: '\u00b7\u00b7\u00b7 ${v.substring(v.length - 6)}',
      vinKind: vin.kind,
      mileageKm: odometer.km,
      inspectionId: id,
      inspectionStatus: 'in_progress',
      sellerPhone: sellerPhone,
    );
  }

  /// Библиотека осмотров исполнителя. В `MockFixtures.orders()` её нет намеренно (общая
  /// фикстура всех suites) — тесты кладут записи сами.
  List<LibraryInspection> library = [];

  /// Срок библиотеки — как у сервера (`InspectionLibrary::DAYS`).
  int libraryDays = 30;

  /// Последний прикреплённый осмотр — для тестов.
  int? lastAttachedInspectionId;

  @override
  Future<InspectionLibraryPage> fetchInspectionLibrary(int orderId) async =>
      InspectionLibraryPage(items: [...library], days: libraryDays);

  @override
  Future<OrderCar> attachFromLibrary(int orderId, int inspectionId) async {
    final item = library.firstWhere((i) => i.inspectionId == inspectionId);
    lastAttachedInspectionId = inspectionId;
    library = [...library]..remove(item);
    // как сервер: кандидат с готовым осмотром, вердиктом и датой
    final source = item.car;
    final car = OrderCar(
      id: source.id,
      brand: source.brand,
      model: source.model,
      year: source.year,
      vinMasked: source.vinMasked,
      vinKind: source.vinKind,
      mileageKm: source.mileageKm,
      inspectionId: item.inspectionId,
      inspectionStatus: 'completed',
      verdict: item.verdict,
      verdictComment: item.verdictComment,
      sellerPhone: source.sellerPhone,
      fromLibrary: true,
      inspectionCompletedAt: item.completedAt,
    );
    final order = _orders.firstWhere((o) => o.id == orderId);
    _replace(
      order.copyWith(
        cars: [...order.cars, car],
        status: order.status == OrderStatus.sourcing
            ? OrderStatus.inspecting
            : order.status,
      ),
    );
    return car;
  }

  /// Телефон продавца последнего кандидата — для тестов экрана кандидата.
  String? lastSellerPhone;

  @override
  Future<OrderCar> updateCarSellerPhone(
    int orderId,
    int carId,
    String? sellerPhone,
  ) async {
    final order = await fetchOrder(orderId);
    final car = order.cars
        .firstWhere((c) => c.id == carId)
        .withSellerPhone(sellerPhone);
    _replace(
      order.copyWith(
        cars: [for (final c in order.cars) c.id == carId ? car : c],
      ),
    );
    return car;
  }

  /// Последний VIN, снятый исполнителем, — для тестов экранов начала осмотра.
  CapturedVin? lastVin;

  /// Последний пробег по одометру — для тех же тестов.
  CapturedOdometer? lastOdometer;

  @override
  Future<Order> payPlacement(int orderId) async {
    final order = await fetchOrder(orderId);
    if (order.status != OrderStatus.awaitingPlacement) {
      throw ApiException(422, '{"message":"Заказ не ждёт оплаты размещения"}');
    }
    if (order.pendingPayment != null) return order;
    final updated = order.copyWith(
      pendingPayment: order.isInspection
          ? backend.startPayment(
              order.placementFee ?? backend.placementFee,
              'inspection_placement',
              orderId: orderId,
            )
          : backend.startPayment(
              order.placementFee ?? backend.selectionPlacementFee,
              'selection_placement',
              orderId: orderId,
            ),
    );
    return _replace(updated);
  }

  @override
  Future<int> startInspection(
    int orderId,
    int carId, {
    required CapturedVin vin,
    required CapturedOdometer odometer,
  }) async {
    lastVin = vin;
    lastOdometer = odometer;
    return carId;
  }

  @override
  Future<Order> leaveReview(
    int orderId, {
    required int rating,
    String? text,
  }) async {
    final order = await fetchOrder(orderId);
    final e = order.executor!;
    // как сервер: сумма оценок растёт, отзыв один, can_review гаснет
    final sum = (e.rating ?? 0) * e.reviewsCount + rating;
    final updated = order.copyWith(
      review: _review(rating, text),
      actions: _set(order.actions, OrderAction.review, false),
      executor: _withRating(e, sum, e.reviewsCount + 1),
    );
    return _replace(updated);
  }

  @override
  Future<Order> updateReview(
    int orderId, {
    required int rating,
    String? text,
  }) async {
    final order = await fetchOrder(orderId);
    final e = order.executor!;
    final old = order.review!;
    final sum = (e.rating ?? 0) * e.reviewsCount - old.rating + rating;
    final updated = order.copyWith(
      review: Review(
        id: old.id,
        rating: rating,
        text: text,
        editableUntil: old.editableUntil,
        createdAt: old.createdAt,
      ),
      executor: _withRating(e, sum, e.reviewsCount),
    );
    return _replace(updated);
  }

  Review _review(int rating, String? text) {
    final now = DateTime.now();
    return Review(
      id: now.millisecondsSinceEpoch,
      rating: rating,
      text: (text == null || text.trim().isEmpty) ? null : text.trim(),
      editableUntil: now.add(const Duration(hours: 24)),
      createdAt: now,
    );
  }

  UserSummary _withRating(UserSummary e, double sum, int count) => UserSummary(
    id: e.id,
    name: e.name,
    rating: count == 0 ? null : (sum / count * 10).round() / 10,
    reviewsCount: count,
    completedOrdersCount: e.completedOrdersCount,
  );

  @override
  Future<Order> declineOrder(int orderId) async {
    final order = await fetchOrder(orderId);
    final updated = order.copyWith(
      // подбор, как сервер, ждёт решения заказчика: заново или отменить
      status: order.isInspection
          ? OrderStatus.awaitingExecutor
          : OrderStatus.awaitingDecision,
      decisionReason: order.isInspection
          ? null
          : DecisionReason.executorReleased,
      clearExecutor: true,
      // подбор, как сервер: готовые отчёты остаются, начатые осмотры — нет
      cars: order.isInspection
          ? null
          : order.cars
                .where((c) => c.inspectionStatus != 'in_progress')
                .toList(),
      responses: [
        for (final r in order.responses)
          r.status == OrderResponseStatus.accepted
              ? OrderResponse(
                  id: r.id,
                  status: OrderResponseStatus.declined,
                  proposedPrice: r.proposedPrice,
                  message: r.message,
                  executor: r.executor,
                )
              : r,
      ],
    );
    return _replace(updated);
  }

  @override
  Future<Order> markPaymentSent(int orderId) async {
    final order = await fetchOrder(orderId);
    final updated = order.copyWith(
      status: OrderStatus.paymentSent,
      paymentSentAt: DateTime.now(),
      // как сервер: новое ожидание — спор заказчику только через сутки
      actions: _set(order.actions, OrderAction.dispute, false),
      disputeAvailableAt: DateTime.now().add(const Duration(hours: 24)),
    );
    return _replace(updated);
  }

  @override
  Future<Order> confirmPayment(int orderId) async {
    final order = await fetchOrder(orderId);
    final now = DateTime.now();
    final updated = order.copyWith(
      status: OrderStatus.completed,
      paymentConfirmedAt: now,
      completedAt: now,
      actions: _set(order.actions, OrderAction.review, true),
      clearPayment: true,
    );
    return _replace(updated);
  }

  @override
  Future<Order> openDispute(int orderId, {required String reason}) async {
    final order = await fetchOrder(orderId);
    final updated = order.copyWith(
      status: OrderStatus.disputed,
      clearDisputeWindow: true,
      dispute: OrderDispute(
        openedBy: MockFixtures.me.id,
        reason: reason,
        openedAt: DateTime.now(),
      ),
    );
    return _replace(updated);
  }

  /// Сохранить заказ и отдать его с картой действий, как сервер.
  Order _replace(Order updated) => backend.replaceOrder(updated);
}
