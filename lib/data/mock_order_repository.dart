import '../models/inspection_type.dart';
import '../models/inspection_verdict.dart';
import '../models/order.dart';
import '../models/order_car.dart';
import '../models/order_kind.dart';
import '../models/order_response.dart';
import '../models/order_response_status.dart';
import '../models/order_status.dart';
import '../models/time_slot.dart';
import '../models/user_summary.dart';
import 'order_repository.dart';

/// Фейковые заказы по мотивам мокапа (design/app_auto_podbor.html,
/// экран "Мои заказы") — для UI-разработки и виджет-тестов без бекенда.
class MockOrderRepository implements OrderRepository {
  MockOrderRepository() : _orders = _seed();

  final List<Order> _orders;

  static const _me = UserSummary(id: 1, name: 'Андрей С.');

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
          executor: const UserSummary(id: 10, name: 'Максим К.'),
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
              executor: UserSummary(id: 14, name: 'Сергей П.'),
            ),
            OrderResponse(
              id: 22,
              status: OrderResponseStatus.pending,
              proposedPrice: 3500,
              executor: UserSummary(id: 10, name: 'Максим К.'),
            ),
            OrderResponse(
              id: 23,
              status: OrderResponseStatus.pending,
              proposedPrice: 4500,
              executor: UserSummary(id: 15, name: 'Олег К.'),
            ),
          ],
        ),
        Order(
          id: 2047,
          kind: OrderKind.inspection,
          status: OrderStatus.completed,
          brand: 'Hyundai',
          model: 'Creta',
          yearFrom: 2020,
          mileageTo: 71000,
          customer: _me,
          executor: const UserSummary(id: 10, name: 'Максим К.'),
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
          executor: UserSummary(id: 10, name: 'Максим К.'),
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
  Future<List<Order>> fetchAvailableOrders() async =>
      _orders.where((o) => o.status == OrderStatus.awaitingExecutor).toList();

  @override
  Future<List<Order>> fetchAssignedOrders() async =>
      _orders.where((o) => o.executor != null).toList();

  @override
  Future<Order> fetchOrder(int id) async => _orders.firstWhere((o) => o.id == id);

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
    final updated = order.copyWith(
      status: OrderStatus.completed,
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
  Future<Order> respondToOrder(int orderId, {required int proposedPrice, String? message}) async {
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
      // как на бекенде (Order::acceptResponse): остальные отклики отклоняются
      responses: [
        for (final r in order.responses)
          OrderResponse(
            id: r.id,
            status: r.id == responseId
                ? OrderResponseStatus.accepted
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

  void _replace(Order updated) {
    final i = _orders.indexWhere((o) => o.id == updated.id);
    if (i != -1) _orders[i] = updated;
  }
}
