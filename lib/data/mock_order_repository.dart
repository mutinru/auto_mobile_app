import '../models/inspection_outcome.dart';
import '../models/inspection_type.dart';
import '../models/inspection_verdict.dart';
import '../models/order.dart';
import '../models/order_car.dart';
import '../models/order_kind.dart';
import '../models/order_response.dart';
import '../models/order_response_status.dart';
import '../models/order_status.dart';
import '../models/payout.dart';
import '../models/report_summary.dart';
import '../models/review.dart';
import '../models/time_slot.dart';
import '../models/user_summary.dart';
import 'order_repository.dart';

/// Фейковые заказы по мотивам мокапа (design/app_auto_podbor.html,
/// экран "Мои заказы") — для UI-разработки и виджет-тестов без бекенда.
class MockOrderRepository implements OrderRepository {
  /// [orders] — свой набор вместо общей фикстуры: тестам оплаты нужны
  /// заказы в reportReady/paymentSent, а правка [_seed] двигает вёрстку
  /// соседних suites.
  MockOrderRepository({List<Order>? orders}) : _orders = orders ?? _seed();

  /// Реквизиты, которые мок отдаёт заказчику в момент оплаты.
  static const mockPayout = Payout(card: '2200700000000009', phone: '+79000000001', bank: 'Т-Банк');

  final List<Order> _orders;

  static const _me = UserSummary(id: 1, name: 'Андрей С.');

  // сводка исполнителей — чтобы в откликах были и рейтинг, и «новый»
  static const _maxim = UserSummary(
    id: 10,
    name: 'Максим К.',
    rating: 4.9,
    reviewsCount: 12,
    completedOrdersCount: 30,
  );
  static const _sergey = UserSummary(
    id: 14,
    name: 'Сергей П.',
    rating: 4.7,
    reviewsCount: 5,
    completedOrdersCount: 8,
  );
  static const _oleg = UserSummary(id: 15, name: 'Олег К.');

  static List<Order> _seed() => [
        // разовые осмотры (order-types.html, кадры 01 и 05)
        Order(
          id: 2051,
          kind: OrderKind.inspection,
          status: OrderStatus.scheduled,
          brand: 'Kia',
          model: 'Rio',
          yearFrom: 2019,
          mileageTo: 64000,
          customer: _me,
          executor: _maxim,
          address: 'Химки, ул. Ленина, 5',
          inspectOn: DateTime.now().add(const Duration(days: 1)),
          timeSlot: TimeSlot.exact,
          inspectTime: '16:00',
          askingPrice: 4000,
          price: 4000,
          sellerPhone: '+79161234567',
          cars: const [
            OrderCar(
              id: 511,
              brand: 'Kia',
              model: 'Rio',
              year: 2019,
              vinMasked: '—',
              mileageKm: 64000,
            ),
          ],
        ),
        Order(
          id: 2053,
          kind: OrderKind.inspection,
          status: OrderStatus.awaitingExecutor,
          brand: 'BMW',
          model: 'X3',
          yearFrom: 2017,
          mileageTo: 112000,
          customer: _me,
          address: 'Москва, Варшавское ш., 170',
          inspectOn: DateTime.now().add(const Duration(days: 3)),
          timeSlot: TimeSlot.day,
          askingPrice: 3500,
          listingUrl: 'auto.ru/cars/used/sale/bmw/x3/1120000123',
          responses: const [
            OrderResponse(
              id: 21,
              status: OrderResponseStatus.pending,
              proposedPrice: 3000,
              executor: _sergey,
            ),
            OrderResponse(
              id: 22,
              status: OrderResponseStatus.pending,
              proposedPrice: 3500,
              executor: _maxim,
            ),
            OrderResponse(
              id: 23,
              status: OrderResponseStatus.pending,
              proposedPrice: 4500,
              executor: _oleg,
            ),
          ],
        ),
        Order(
          id: 2047,
          kind: OrderKind.inspection,
          status: OrderStatus.completed,
          completedAt: DateTime.now().subtract(const Duration(days: 2)),
          canReview: true,
          brand: 'Hyundai',
          model: 'Creta',
          yearFrom: 2020,
          mileageTo: 71000,
          customer: _me,
          executor: _maxim,
          address: 'Мытищи, ул. Мира, 12',
          inspectOn: DateTime.now().subtract(const Duration(days: 2)),
          timeSlot: TimeSlot.morning,
          askingPrice: 4000,
          price: 4000,
          cars: const [
            OrderCar(
              id: 512,
              brand: 'Hyundai',
              model: 'Creta',
              year: 2020,
              vinMasked: '··· 100077',
              mileageKm: 71000,
              inspectionId: 90,
              inspectionStatus: 'completed',
              verdict: InspectionVerdict.notRecommended,
              verdictComment: '3 детали перекрашены, замена крыла',
            ),
          ],
        ),
        const Order(
          id: 2041,
          status: OrderStatus.inspecting,
          brand: 'Toyota',
          model: 'Camry',
          yearFrom: 2018,
          budgetMin: 2000000,
          budgetMax: 2400000,
          customer: _me,
          executor: _maxim,
          price: 12000,
        ),
        const Order(
          id: 2038,
          status: OrderStatus.sourcing,
          brand: 'Kia',
          model: 'Sportage',
          yearFrom: 2021,
          budgetMax: 3100000,
          customer: _me,
          executor: UserSummary(id: 11, name: 'Игорь В.'),
          price: 15000,
        ),
        const Order(
          id: 2044,
          status: OrderStatus.awaitingExecutor,
          brand: 'Volkswagen',
          model: 'Tiguan',
          yearFrom: 2019,
          budgetMax: 2000000,
          customer: _me,
          responses: [
            OrderResponse(
              id: 1,
              status: OrderResponseStatus.pending,
              proposedPrice: 10000,
              executor: UserSummary(id: 12, name: 'Денис П.'),
            ),
          ],
        ),
      ];

  @override
  Future<List<Order>> fetchMyOrders() async => _orders;

  @override
  Future<List<Order>> fetchAvailableOrders() async => _orders
      .where((o) => o.status == OrderStatus.awaitingExecutor)
      .map(_asExecutor)
      .toList();

  /// Как бекенд (OrderResource): не заказчику — только свой отклик,
  /// общее число — в responsesCount.
  static Order _asExecutor(Order o) => o.copyWith(
        responses: o.responses.where((r) => r.executor.id == _me.id).toList(),
        responsesCount: o.responses.length,
      );

  @override
  Future<List<Order>> fetchAssignedOrders() async =>
      _orders.where((o) => o.executor != null).toList();

  @override
  Future<Order> fetchOrder(int id) async => _withCanCancel(_orders.firstWhere((o) => o.id == id));

  /// Имитация сервера (Order::canBeCancelledBy): свой заказ до выбора
  /// исполнителя. Экраны правило не повторяют — только читают флаг.
  static Order _withCanCancel(Order o) => o.copyWith(
        canCancel: o.customer.id == _me.id && o.status == OrderStatus.awaitingExecutor,
      );

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
    final order = Order(
      id: DateTime.now().millisecondsSinceEpoch,
      status: OrderStatus.awaitingExecutor,
      brand: brand,
      model: model,
      yearFrom: yearFrom,
      mileageTo: mileageTo,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      cities: cities,
      requirements: requirements,
      comment: comment,
      customer: _me,
    );
    _orders.insert(0, order);
    return order;
  }

  @override
  Future<Order> createInspectionOrder({
    required String brand,
    required String model,
    required int year,
    required int mileageKm,
    required String address,
    required DateTime inspectOn,
    required TimeSlot timeSlot,
    required int askingPrice,
    String? inspectTime,
    String? vin,
    String? listingUrl,
    String? sellerPhone,
    String? comment,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final order = Order(
      id: id,
      kind: OrderKind.inspection,
      status: OrderStatus.awaitingExecutor,
      brand: brand,
      model: model,
      yearFrom: year,
      mileageTo: mileageKm,
      customer: _me,
      address: address,
      inspectOn: inspectOn,
      timeSlot: timeSlot,
      inspectTime: timeSlot == TimeSlot.exact ? inspectTime : null,
      askingPrice: askingPrice,
      listingUrl: listingUrl,
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
          mileageKm: mileageKm,
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
      payout: mockPayout,
      reportSummary: const ReportSummary(
        panelsTotal: 13,
        panelsInspected: 13,
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
          inspectionId: car.inspectionId,
          inspectionStatus: 'completed',
          verdict: verdict,
          verdictComment: comment,
        ),
      ],
    );
    _replace(updated);
    return updated;
  }

  @override
  Future<Order> respondToOrder(
    int orderId, {
    required int proposedPrice,
    String? message,
    Payout? payout,
  }) async {
    final order = await fetchOrder(orderId);
    final updated = order.copyWith(
      responses: [
        ...order.responses,
        OrderResponse(
          id: order.responses.length + 1,
          status: OrderResponseStatus.pending,
          proposedPrice: proposedPrice,
          message: message,
          executor: _me,
        ),
      ],
    );
    _replace(updated);
    return _asExecutor(updated);
  }

  @override
  Future<Order> completeSelection(int orderId, {required int carId}) async {
    final order = await fetchOrder(orderId);
    final updated = order.copyWith(
      status: OrderStatus.completed,
      completedAt: DateTime.now(),
      canReview: order.executor != null,
      // как Order::complete(): исход только у кандидатов с осмотром
      cars: [
        for (final c in order.cars)
          c.inspectionId == null
              ? c
              : OrderCar(
                  id: c.id,
                  brand: c.brand,
                  model: c.model,
                  year: c.year,
                  vinMasked: c.vinMasked,
                  mileageKm: c.mileageKm,
                  inspectionId: c.inspectionId,
                  inspectionStatus: c.inspectionStatus,
                  inspectionOutcome:
                      c.id == carId ? InspectionOutcome.purchased : InspectionOutcome.rejected,
                ),
      ],
    );
    _replace(updated);
    return updated;
  }

  @override
  Future<Order> cancelOrder(int orderId) async {
    final order = await fetchOrder(orderId);
    final updated = order.copyWith(
      status: OrderStatus.cancelled,
      canCancel: false,
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
    _replace(updated);
    return updated;
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
      executorDeadlineAt: order.isInspection ? DateTime.now().add(const Duration(hours: 24)) : null,
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
    _replace(updated);
    return updated;
  }

  @override
  Future<OrderCar> addCar(
    int orderId, {
    required String brand,
    required String model,
    required int year,
    required String vin,
    required int mileageKm,
    String? licensePlate,
  }) async {
    return OrderCar(
      id: DateTime.now().millisecondsSinceEpoch,
      brand: brand,
      model: model,
      year: year,
      vinMasked: '\u00b7\u00b7\u00b7 ${vin.substring(vin.length - 6)}',
      mileageKm: mileageKm,
    );
  }

  @override
  Future<int> startInspection(
    int orderId,
    int carId, {
    InspectionType type = InspectionType.full,
  }) async =>
      carId;

  @override
  Future<Order> leaveReview(int orderId, {required int rating, String? text}) async {
    final order = await fetchOrder(orderId);
    final e = order.executor!;
    // как сервер: сумма оценок растёт, отзыв один, can_review гаснет
    final sum = (e.rating ?? 0) * e.reviewsCount + rating;
    final updated = order.copyWith(
      review: _review(rating, text),
      canReview: false,
      executor: _withRating(e, sum, e.reviewsCount + 1),
    );
    _replace(updated);
    return updated;
  }

  @override
  Future<Order> updateReview(int orderId, {required int rating, String? text}) async {
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
    _replace(updated);
    return updated;
  }

  @override
  Future<ReviewPage> fetchExecutorReviews(int userId, {int page = 1}) async {
    final now = DateTime.now();
    return ReviewPage(
      items: [
        Review(
          id: 1,
          rating: 5,
          text: 'Нашёл машину за неделю, все косяки показал на месте.',
          editableUntil: now,
          createdAt: now.subtract(const Duration(days: 3)),
          customer: _me,
          orderTitle: 'Kia Sportage',
        ),
        Review(
          id: 2,
          rating: 4,
          editableUntil: now,
          createdAt: now.subtract(const Duration(days: 20)),
          customer: _me,
          orderTitle: 'Skoda Octavia',
        ),
      ],
      hasMore: false,
    );
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
      status: OrderStatus.awaitingExecutor,
      clearExecutor: true,
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
    _replace(updated);
    return updated;
  }

  @override
  Future<Order> markPaymentSent(int orderId) async {
    final order = await fetchOrder(orderId);
    final updated = order.copyWith(status: OrderStatus.paymentSent, paymentSentAt: DateTime.now());
    _replace(updated);
    return updated;
  }

  @override
  Future<Order> confirmPayment(int orderId) async {
    final order = await fetchOrder(orderId);
    final now = DateTime.now();
    final updated = order.copyWith(
      status: OrderStatus.completed,
      paymentConfirmedAt: now,
      completedAt: now,
      canReview: true,
      clearPayment: true,
    );
    _replace(updated);
    return updated;
  }

  @override
  Future<Order> openDispute(int orderId, {required String reason}) async {
    final order = await fetchOrder(orderId);
    final updated = order.copyWith(
      status: OrderStatus.disputed,
      dispute: OrderDispute(openedBy: _me.id, reason: reason, openedAt: DateTime.now()),
    );
    _replace(updated);
    return updated;
  }

  void _replace(Order updated) {
    final i = _orders.indexWhere((o) => o.id == updated.id);
    if (i != -1) _orders[i] = updated;
  }
}
