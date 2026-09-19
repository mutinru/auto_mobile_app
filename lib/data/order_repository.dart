import '../models/inspection_type.dart';
import '../models/inspection_verdict.dart';
import '../models/order.dart';
import '../models/order_car.dart';
import '../models/time_slot.dart';

/// Источник данных маркетплейса заказов. Как и InspectionRepository —
/// две реализации: [MockOrderRepository] для UI без бекенда,
/// [ApiOrderRepository] поверх Laravel API (routes/api.php, группа orders).
abstract class OrderRepository {
  Future<List<Order>> fetchMyOrders();
  Future<List<Order>> fetchAvailableOrders();

  /// Заказы, где пользователь — назначенный исполнитель.
  Future<List<Order>> fetchAssignedOrders();
  Future<Order> fetchOrder(int id);

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
  });

  /// Разовый осмотр конкретной машины: бекенд заводит заказ и его
  /// единственную Car в одной транзакции (order-types.html, кадр 03).
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
  });

  /// Завершить разовый осмотр вердиктом (исполнитель).
  Future<Order> completeInspection(
    int orderId, {
    required InspectionVerdict verdict,
    String? comment,
  });

  Future<Order> respondToOrder(int orderId, {required int proposedPrice, String? message});

  Future<Order> acceptResponse(int orderId, int responseId);

  /// Завести кандидата в рамках заказа (исполнитель нашёл вариант).
  Future<OrderCar> addCar(
    int orderId, {
    required String brand,
    required String model,
    required int year,
    required String vin,
    required int mileageKm,
    String? licensePlate,
  });

  /// Начать осмотр кандидата — бекенд сам создаёт 13 деталей.
  /// Возвращает id созданного осмотра.
  Future<int> startInspection(
    int orderId,
    int carId, {
    InspectionType type = InspectionType.full,
  });
}
