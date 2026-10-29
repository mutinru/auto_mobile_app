import 'inspection_verdict.dart';
import 'order_car.dart';
import 'order_kind.dart';
import 'order_response.dart';
import 'order_status.dart';
import 'payout.dart';
import 'report_summary.dart';
import 'review.dart';
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
    this._responsesCount,
    this.cars = const [],
    this.completedAt,
    this.review,
    this.canReview = false,
    this.canCancel = false,
    this.executorDeadlineAt,
    this.paymentSentAt,
    this.paymentConfirmedAt,
    this.dispute,
    this.payout,
    this.reportSummary,
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
  /// Заказчику — все отклики, исполнителю — только свой (или пусто):
  /// чужие цены и сообщения сервер не отдаёт.
  final List<OrderResponse> responses;

  final int? _responsesCount;

  /// Сколько всего откликов. Считать по `responses.length` нельзя — у
  /// исполнителя там максимум один. Без ключа в ответе (моки) — длина списка.
  int get responsesCount => _responsesCount ?? responses.length;

  /// Исполнитель уже откликался — сервер отдаёт ему только его отклик, и
  /// второй (в любом статусе) отклонит с 422. Смысл есть только в ленте
  /// исполнителя: заказчик видит все отклики, но свои заказы в ленту не
  /// попадают.
  bool get hasViewerResponse => responses.isNotEmpty;

  final List<OrderCar> cars;

  final DateTime? completedAt;

  /// Отзыв заказчика об исполнителе. Ключи review/can_review бекенд отдаёт
  /// только в карточке заказа, /orders/mine и ответах завершения — в
  /// остальных списках их нет, и это читается как «нет отзыва, нельзя».
  final Review? review;

  /// Сервер разрешает оставить отзыв прямо сейчас (заказчик, completed,
  /// отзыва нет, 30 дней не прошли). Локально не вычисляем.
  final bool canReview;

  /// Сервер разрешает заказчику отменить заказ (сейчас — до выбора
  /// исполнителя, с оплатой заказа — до оплаты). Локально не вычисляем:
  /// правило меняется на бекенде без новой сборки.
  final bool canCancel;

  /// До какого момента исполнитель разового осмотра должен довести его до
  /// «отчёт готов» (24 часа с выбора). Истечение отрабатывает сервер.
  final DateTime? executorDeadlineAt;
  final DateTime? paymentSentAt;
  final DateTime? paymentConfirmedAt;

  /// Только сторонам заказа и только когда спор открыт.
  final OrderDispute? dispute;

  /// Реквизиты исполнителя — сервер отдаёт их только заказчику и только пока
  /// идёт оплата (reportReady, paymentSent, disputed).
  final Payout? payout;

  /// Сводка отчёта до оплаты — тому же заказчику в тех же статусах.
  final ReportSummary? reportSummary;

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
    int? responsesCount,
    List<OrderCar>? cars,
    Review? review,
    bool? canReview,
    bool? canCancel,
    DateTime? executorDeadlineAt,
    DateTime? paymentSentAt,
    OrderDispute? dispute,
    Payout? payout,
    ReportSummary? reportSummary,
    DateTime? paymentConfirmedAt,
    DateTime? completedAt,
    // исполнитель снят (отказ или 24 часа) — null через `executor` не передать
    bool clearExecutor = false,
    // оплата подтверждена: реквизиты и сводку сервер больше не отдаёт
    bool clearPayment = false,
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
        executor: clearExecutor ? null : (executor ?? this.executor),
        responses: responses ?? this.responses,
        // новый список без числа — считаем по нему, иначе счётчик устареет
        responsesCount: responsesCount ?? (responses != null ? null : _responsesCount),
        cars: cars ?? this.cars,
        completedAt: completedAt ?? this.completedAt,
        review: review ?? this.review,
        canReview: canReview ?? this.canReview,
        canCancel: canCancel ?? this.canCancel,
        executorDeadlineAt: clearExecutor ? null : (executorDeadlineAt ?? this.executorDeadlineAt),
        paymentSentAt: paymentSentAt ?? this.paymentSentAt,
        paymentConfirmedAt: paymentConfirmedAt ?? this.paymentConfirmedAt,
        dispute: dispute ?? this.dispute,
        payout: clearPayment ? null : (payout ?? this.payout),
        reportSummary: clearPayment ? null : (reportSummary ?? this.reportSummary),
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
        responsesCount: json['responses_count'] as int?,
        cars: (json['cars'] as List? ?? const [])
            .map((c) => OrderCar.fromJson(c as Map<String, dynamic>))
            .toList(),
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String).toLocal()
            : null,
        review: json['review'] != null
            ? Review.fromJson(json['review'] as Map<String, dynamic>)
            : null,
        canReview: json['can_review'] as bool? ?? false,
        canCancel: json['can_cancel'] as bool? ?? false,
        executorDeadlineAt: _date(json['executor_deadline_at']),
        paymentSentAt: _date(json['payment_sent_at']),
        paymentConfirmedAt: _date(json['payment_confirmed_at']),
        dispute: json['dispute'] != null
            ? OrderDispute.fromJson(json['dispute'] as Map<String, dynamic>)
            : null,
        payout: json['payout'] != null
            ? Payout.fromJson(json['payout'] as Map<String, dynamic>)
            : null,
        reportSummary: json['report_summary'] != null
            ? ReportSummary.fromJson(json['report_summary'] as Map<String, dynamic>)
            : null,
      );

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.parse(value).toLocal() : null;
}
