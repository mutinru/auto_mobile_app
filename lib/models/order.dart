import 'inspection_verdict.dart';
import 'order_car.dart';
import 'order_kind.dart';
import 'order_response.dart';
import 'order_status.dart';
import 'time_slot.dart';
import 'user_summary.dart';

/// Зеркалит OrderResource на бекенде (app/Http/Resources/OrderResource.php).
/// Поля с address по askingPrice заполнены только у заказа-осмотра
/// (kind == OrderKind.inspection), у подбора они null.
class Order {
  const Order({
    required this.id,
    required this.status,
    required this.brand,
    required this.model,
    required this.customer,
    this.kind = OrderKind.selection,
    this.yearFrom,
    this.mileageTo,
    this.budgetMin,
    this.budgetMax,
    this.cities = const [],
    this.requirements = const [],
    this.comment,
    this.price,
    this.address,
    this.inspectOn,
    this.timeSlot,
    this.inspectTime,
    this.listingUrl,
    this.sellerPhone,
    this.askingPrice,
    this.executor,
    this.responses = const [],
    this.cars = const [],
  });

  final int id;
  final OrderKind kind;
  final OrderStatus status;
  final String brand;
  final String model;
  final int? yearFrom;
  final int? mileageTo;
  final int? budgetMin;
  final int? budgetMax;
  final List<String> cities;
  final List<String> requirements;
  final String? comment;

  /// Согласованный гонорар из принятого отклика.
  final int? price;

  final String? address;
  final DateTime? inspectOn;
  final TimeSlot? timeSlot;

  /// «16:00» — только когда timeSlot == TimeSlot.exact.
  final String? inspectTime;
  final String? listingUrl;

  /// Телефон продавца: бекенд отдаёт его только заказчику и выбранному
  /// исполнителю, остальным ключа в ответе просто нет.
  final String? sellerPhone;

  /// Цена, которую назначил заказчик (у осмотра — точка отсчёта для откликов).
  final int? askingPrice;

  final UserSummary customer;
  final UserSummary? executor;
  final List<OrderResponse> responses;
  final List<OrderCar> cars;

  bool get isInspection => kind.isInspection;

  /// У подбора «Kia Sportage 2021+» (год — нижняя граница),
  /// у осмотра машина конкретная: «Kia Rio 2019».
  String get carTitle {
    if (yearFrom == null) return '$brand $model';
    return '$brand $model $yearFrom${isInspection ? '' : '+'}';
  }

  /// Вердикт завершённого осмотра (у заказа-осмотра машина одна).
  InspectionVerdict? get verdict => cars.isEmpty ? null : cars.first.verdict;

  Order copyWith({
    OrderStatus? status,
    int? price,
    UserSummary? executor,
    List<OrderResponse>? responses,
    List<OrderCar>? cars,
  }) =>
      Order(
        id: id,
        kind: kind,
        status: status ?? this.status,
        brand: brand,
        model: model,
        yearFrom: yearFrom,
        mileageTo: mileageTo,
        budgetMin: budgetMin,
        budgetMax: budgetMax,
        cities: cities,
        requirements: requirements,
        comment: comment,
        price: price ?? this.price,
        address: address,
        inspectOn: inspectOn,
        timeSlot: timeSlot,
        inspectTime: inspectTime,
        listingUrl: listingUrl,
        sellerPhone: sellerPhone,
        askingPrice: askingPrice,
        customer: customer,
        executor: executor ?? this.executor,
        responses: responses ?? this.responses,
        cars: cars ?? this.cars,
      );

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as int,
        kind: orderKindFromApi(json['kind'] as String?),
        status: orderStatusFromApi(json['status'] as String),
        brand: json['brand'] as String,
        model: json['model'] as String,
        yearFrom: json['year_from'] as int?,
        mileageTo: json['mileage_to'] as int?,
        budgetMin: json['budget_min'] as int?,
        budgetMax: json['budget_max'] as int?,
        cities: (json['cities'] as List?)?.cast<String>() ?? const [],
        requirements: (json['requirements'] as List?)?.cast<String>() ?? const [],
        comment: json['comment'] as String?,
        price: json['price'] as int?,
        address: json['address'] as String?,
        // с бекенда приходит 'Y-m-d' — DateTime.parse даёт локальную полночь
        inspectOn: json['inspect_on'] != null
            ? DateTime.parse(json['inspect_on'] as String)
            : null,
        timeSlot: timeSlotFromApi(json['time_slot'] as String?),
        inspectTime: json['inspect_time'] as String?,
        listingUrl: json['listing_url'] as String?,
        sellerPhone: json['seller_phone'] as String?,
        askingPrice: json['asking_price'] as int?,
        customer: UserSummary.fromJson(json['customer'] as Map<String, dynamic>),
        executor: json['executor'] != null
            ? UserSummary.fromJson(json['executor'] as Map<String, dynamic>)
            : null,
        responses: (json['responses'] as List? ?? const [])
            .map((r) => OrderResponse.fromJson(r as Map<String, dynamic>))
            .toList(),
        cars: (json['cars'] as List? ?? const [])
            .map((c) => OrderCar.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}
