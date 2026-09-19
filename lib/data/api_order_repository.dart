import '../models/inspection_type.dart';
import '../models/inspection_verdict.dart';
import '../models/order.dart';
import '../models/order_car.dart';
import '../models/time_slot.dart';
import 'api_client.dart';
import 'order_repository.dart';

class ApiOrderRepository implements OrderRepository {
  ApiOrderRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<Order>> fetchMyOrders() async {
    final json = await _client.get('/orders/mine');
    return _parseList(json);
  }

  @override
  Future<List<Order>> fetchAvailableOrders() async {
    final json = await _client.get('/orders/available');
    return _parseList(json);
  }

  @override
  Future<List<Order>> fetchAssignedOrders() async {
    final json = await _client.get('/orders/assigned');
    return _parseList(json);
  }

  @override
  Future<Order> fetchOrder(int id) async {
    final json = await _client.get('/orders/$id');
    return Order.fromJson(json['data'] as Map<String, dynamic>);
  }

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
    final body = <String, dynamic>{
      'brand': brand,
      'model': model,
      'year_from': ?yearFrom,
      'mileage_to': ?mileageTo,
      'budget_min': ?budgetMin,
      'budget_max': ?budgetMax,
      if (cities.isNotEmpty) 'cities': cities,
      if (requirements.isNotEmpty) 'requirements': requirements,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    };
    final json = await _client.post('/orders', body);
    return Order.fromJson(json['data'] as Map<String, dynamic>);
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
    final json = await _client.post('/orders', {
      'kind': 'inspection',
      'brand': brand,
      'model': model,
      'year': year,
      'mileage_km': mileageKm,
      'address': address,
      'inspect_on': _ymd(inspectOn),
      'time_slot': timeSlot.apiValue,
      'asking_price': askingPrice,
      if (timeSlot == TimeSlot.exact && inspectTime != null) 'inspect_time': inspectTime,
      if (vin != null && vin.isNotEmpty) 'vin': vin,
      if (listingUrl != null && listingUrl.isNotEmpty) 'listing_url': listingUrl,
      if (sellerPhone != null && sellerPhone.isNotEmpty) 'seller_phone': sellerPhone,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
    return Order.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<Order> completeInspection(
    int orderId, {
    required InspectionVerdict verdict,
    String? comment,
  }) async {
    final json = await _client.post('/orders/$orderId/inspection/complete', {
      'verdict': verdict.apiValue,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
    return Order.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<Order> respondToOrder(int orderId, {required int proposedPrice, String? message}) async {
    final json = await _client.post('/orders/$orderId/responses', {
      'proposed_price': proposedPrice,
      if (message != null && message.isNotEmpty) 'message': message,
    });
    return Order.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<Order> acceptResponse(int orderId, int responseId) async {
    final json = await _client.post('/orders/$orderId/responses/$responseId/accept');
    return Order.fromJson(json['data'] as Map<String, dynamic>);
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
    final json = await _client.post('/orders/$orderId/cars', {
      'brand': brand,
      'model': model,
      'year': year,
      'vin': vin,
      'mileage_km': mileageKm,
      'license_plate': ?licensePlate,
    });
    return OrderCar.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<int> startInspection(
    int orderId,
    int carId, {
    InspectionType type = InspectionType.full,
  }) async {
    final json = await _client.post(
      '/orders/$orderId/cars/$carId/inspections',
      {'inspection_type': type.apiValue},
    );
    return (json['data'] as Map<String, dynamic>)['id'] as int;
  }

  /// Бекенд ждёт дату без времени — иначе валидация after_or_equal
  /// и cast date:Y-m-d разойдутся на часовом поясе.
  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<Order> _parseList(Map<String, dynamic> json) => (json['data'] as List)
      .map((o) => Order.fromJson(o as Map<String, dynamic>))
      .toList();
}
