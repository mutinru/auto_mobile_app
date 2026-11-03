import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/available_page.dart';
import '../models/inspection_type.dart';
import '../models/inspection_verdict.dart';
import '../models/nearby_filter.dart';
import '../models/order.dart';
import '../models/order_car.dart';
import '../models/payout.dart';
import '../models/review.dart';
import '../models/time_slot.dart';
import '../models/vin_kind.dart';
import '../models/vin_report.dart';
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
  Future<AvailablePage> fetchAvailableOrders({
    NearbyFilter filter = const NearbyFilter(),
    bool fewResponses = false,
    int page = 1,
  }) async {
    final query = [
      filter.toQuery(fewResponses: fewResponses),
      'page=$page',
    ].where((p) => p.isNotEmpty).join('&');
    final json = await _client.get('/orders/available?$query');
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    final facets = meta['facets'] as Map<String, dynamic>?;
    List<Facet>? parse(Object? list) => list is List
        ? [for (final f in list) Facet.fromJson(f as Map<String, dynamic>)]
        : null;
    final items = _parseList(json);
    final current = (meta['current_page'] as num?)?.toInt() ?? page;
    final last = (meta['last_page'] as num?)?.toInt() ?? current;
    return AvailablePage(
      items: items,
      page: current,
      hasMore: current < last,
      total: (meta['total'] as num?)?.toInt() ?? items.length,
      all: (meta['all'] as num?)?.toInt() ?? items.length,
      cityFacets: parse(facets?['cities']),
      brandFacets: parse(facets?['brands']),
    );
  }

  @override
  Future<int> countAvailableOrders({
    NearbyFilter filter = const NearbyFilter(),
    bool fewResponses = false,
  }) async {
    final query = filter.toQuery(fewResponses: fewResponses);
    final json = await _client.get(
      '/orders/available/count${query.isEmpty ? '' : '?$query'}',
    );
    return (json['total'] as num).toInt();
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
    final json = await _client.post('/orders', {
      'kind': 'inspection',
      'brand': brand,
      'model': model,
      'year': year,
      'mileage_km': ?mileageKm,
      'city': city,
      'city_id': ?cityId,
      'address': address,
      if (lat != null && lon != null) ...{
        'lat': lat,
        'lon': lon,
        'address_precision': ?addressPrecision,
      },
      'inspect_on': _ymd(inspectOn),
      'time_slot': timeSlot.apiValue,
      'asking_price': askingPrice,
      if (timeSlot == TimeSlot.exact && inspectTime != null)
        'inspect_time': inspectTime,
      if (vin != null && vin.isNotEmpty) 'vin': vin,
      if (listingUrl != null && listingUrl.isNotEmpty)
        'listing_url': listingUrl,
      if (sellerPhone != null && sellerPhone.isNotEmpty)
        'seller_phone': sellerPhone,
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
  Future<Order> declineOrder(int orderId) =>
      _orderAction('/orders/$orderId/decline');

  @override
  Future<Order> markPaymentSent(int orderId) =>
      _orderAction('/orders/$orderId/payment/sent');

  @override
  Future<Order> confirmPayment(int orderId) =>
      _orderAction('/orders/$orderId/payment/confirm');

  @override
  Future<Order> openDispute(int orderId, {required String reason}) =>
      _orderAction('/orders/$orderId/dispute', {'reason': reason});

  Future<Order> _orderAction(String path, [Map<String, dynamic>? body]) async {
    final json = await _client.post(path, body);
    return Order.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<Order> acceptResponse(int orderId, int responseId) async {
    final json = await _client.post(
      '/orders/$orderId/responses/$responseId/accept',
    );
    return Order.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<Order> completeCandidate(
    int orderId,
    int carId, {
    required InspectionVerdict verdict,
    String? comment,
  }) => _orderAction('/orders/$orderId/cars/$carId/inspection/complete', {
    'verdict': verdict.apiValue,
    if (comment != null && comment.isNotEmpty) 'comment': comment,
  });

  @override
  Future<Order> completeSelection(int orderId, {required int carId}) =>
      _orderAction('/orders/$orderId/complete', {'car_id': carId});

  @override
  Future<Order> cancelOrder(int orderId) =>
      _orderAction('/orders/$orderId/cancel');

  @override
  Future<Order> repostInspection(
    int orderId, {
    required DateTime inspectOn,
    required TimeSlot timeSlot,
    String? inspectTime,
    int? askingPrice,
  }) => _orderAction('/orders/$orderId/repost', {
    'inspect_on': _ymd(inspectOn),
    'time_slot': timeSlot.apiValue,
    if (timeSlot == TimeSlot.exact && inspectTime != null)
      'inspect_time': inspectTime,
    'asking_price': ?askingPrice,
  });

  @override
  Future<Order> leaveReview(
    int orderId, {
    required int rating,
    String? text,
  }) async {
    final json = await _client.post(
      '/orders/$orderId/review',
      _reviewBody(rating, text),
    );
    return Order.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<Order> updateReview(
    int orderId, {
    required int rating,
    String? text,
  }) async {
    final json = await _client.patch(
      '/orders/$orderId/review',
      _reviewBody(rating, text),
    );
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
      hasMore:
          (meta['current_page'] as int? ?? 1) <
          (meta['last_page'] as int? ?? 1),
    );
  }

  @override
  Future<OrderCar> addCar(
    int orderId, {
    required String brand,
    required String model,
    required int year,
    required CapturedVin vin,
    required int mileageKm,
    String? licensePlate,
  }) async {
    final json = await _withVin('/orders/$orderId/cars', vin, {
      'brand': brand,
      'model': model,
      'year': '$year',
      'mileage_km': '$mileageKm',
      'license_plate': ?licensePlate,
    });
    return OrderCar.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<int> startInspection(
    int orderId,
    int carId, {
    InspectionType type = InspectionType.full,
    CapturedVin? vin,
  }) async {
    final path = '/orders/$orderId/cars/$carId/inspections';
    final fields = {'inspection_type': type.apiValue};
    final json = vin == null
        ? await _client.post(path, fields)
        : await _withVin(path, vin, fields);
    return (json['data'] as Map<String, dynamic>)['id'] as int;
  }

  /// VIN с фото таблички — multipart мимо ApiClient (тот умеет только
  /// JSON); ошибки всё равно через [ApiClient.failure], чтобы 401 стёр
  /// сессию, а 422 легли на поля.
  Future<Map<String, dynamic>> _withVin(
    String path,
    CapturedVin vin,
    Map<String, String> fields,
  ) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}$path'))
          ..headers['Accept'] = 'application/json'
          ..headers['Authorization'] = 'Bearer ${_client.token}'
          ..fields.addAll({
            ...fields,
            'vin': vin.value,
            'vin_kind': vin.kind.apiValue,
          })
          ..files.add(
            await http.MultipartFile.fromPath('vin_photo', vin.photoPath),
          );

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw _client.failure(streamed.statusCode, body);
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }

  @override
  Future<VinReportCheck> checkVinReports(String vin) async {
    final json = await _client.get(
      '/vin-reports/check?vin=${Uri.encodeQueryComponent(vin)}',
    );
    return VinReportCheck.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<VinReportPurchase> purchaseVinReport(String vin) async {
    final json = await _client.post('/vin-reports/purchases', {'vin': vin});
    return VinReportPurchase.fromJson(json['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<VinReportPurchase>> fetchVinReportPurchases() async {
    final json = await _client.get('/vin-reports/purchases');
    return [
      for (final p in json['data'] as List)
        VinReportPurchase.fromJson(p as Map<String, dynamic>),
    ];
  }

  @override
  Future<VinReportPurchase> fetchVinReportPurchase(int id) async {
    final json = await _client.get('/vin-reports/purchases/$id');
    return VinReportPurchase.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// Бекенд ждёт дату без времени — иначе валидация after_or_equal
  /// и cast date:Y-m-d разойдутся на часовом поясе.
  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<Order> _parseList(Map<String, dynamic> json) => (json['data'] as List)
      .map((o) => Order.fromJson(o as Map<String, dynamic>))
      .toList();
}
