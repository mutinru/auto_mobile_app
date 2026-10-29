import '../models/inspection_type.dart';
import '../models/inspection_verdict.dart';
import '../models/order.dart';
import '../models/order_car.dart';
import '../models/payout.dart';
import '../models/review.dart';
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
  Future<Order> respondToOrder(
    int orderId, {
    required int proposedPrice,
    String? message,
    Payout? payout,
  }) async {
    final json = await _client.post('/orders/$orderId/responses', {
      'proposed_price': proposedPrice,
      if (message != null && message.isNotEmpty) 'message': message,
      ...?payout?.toJson(),
    });
    return Order.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<Order> declineOrder(int orderId) => _orderAction('/orders/$orderId/decline');

  @override
  Future<Order> markPaymentSent(int orderId) => _orderAction('/orders/$orderId/payment/sent');

  @override
  Future<Order> confirmPayment(int orderId) => _orderAction('/orders/$orderId/payment/confirm');

  @override
  Future<Order> openDispute(int orderId, {required String reason}) =>
      _orderAction('/orders/$orderId/dispute', {'reason': reason});

  Future<Order> _orderAction(String path, [Map<String, dynamic>? body]) async {
    final json = await _client.post(path, body);
    return Order.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<Order> acceptResponse(int orderId, int responseId) async {
    final json = await _client.post('/orders/$orderId/responses/$responseId/accept');
    return Order.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<Order> completeSelection(int orderId, {required int carId}) =>
      _orderAction('/orders/$orderId/complete', {'car_id': carId});

  @override
  Future<Order> cancelOrder(int orderId) => _orderAction('/orders/$orderId/cancel');

  @override
  Future<Order> leaveReview(int orderId, {required int rating, String? text}) async {
    final json = await _client.post('/orders/$orderId/review', _reviewBody(rating, text));
    return Order.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<Order> updateReview(int orderId, {required int rating, String? text}) async {
    final json = await _client.patch('/orders/$orderId/review', _reviewBody(rating, text));
    return Order.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// Пустой текст уходит как null — иначе min:10 на бекенде отклонит
  /// «без комментария» у высокой оценки.
  Map<String, dynamic> _reviewBody(int rating, String? text) => {
        'rating': rating,
        'text': (text == null || text.trim().isEmpty) ? null : text.trim(),
      };

  @override
  Future<ReviewPage> fetchExecutorReviews(int userId, {int page = 1}) async {
    final json = await _client.get('/users/$userId/reviews?page=$page');
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    return ReviewPage(
      items: (json['data'] as List)
          .map((r) => Review.fromJson(r as Map<String, dynamic>))
          .toList(),
      hasMore: (meta['current_page'] as int? ?? 1) < (meta['last_page'] as int? ?? 1),
    );
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
