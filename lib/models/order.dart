import 'inspection_verdict.dart';
import 'order_car.dart';
import 'order_kind.dart';
import 'order_response.dart';
import 'order_response_status.dart';
import 'order_status.dart';
import 'payout.dart';
import 'report_summary.dart';
import 'review.dart';
import 'time_slot.dart';
import 'user_summary.dart';
import '../util/ru_plural.dart';

/// Почему разовый осмотр ждёт решения заказчика: исполнитель сорвал день
/// осмотра или день прошёл, а исполнитель так и не выбран.
enum DecisionReason { missed, datePassed }

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
    this.lat,
    this.lon,
    this.addressPrecision,
    this.inspectOn,
    this.timeSlot,
    this.inspectTime,
    this.listingUrl,
    this.listingHost,
    this.listingSite,
    this.hasListing = false,
    this.sellerPhone,
    this.counterpartPhone,
    this.askingPrice,
    this.executor,
    this.responses = const [],
    this._responsesCount,
    this.cars = const [],
    this.completedAt,
    this.cancelledAt,
    this.review,
    this.canReview = false,
    this.canCancel = false,
    this.canDispute = false,
    this.disputeAvailableAt,
    this.executorDeadlineAt,
    this.decisionReason,
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

  /// Улица и дом осмотра, без города — город в [cities]. Сервер отдаёт его
  /// только заказчику и выбранному исполнителю, остальным ключа нет.
  final String? address;

  /// Точка осмотра: из подсказки адреса или центр города. Не сторонам
  /// заказа сервер округляет её до ~1 км — для «· 8 км» в ленте хватает.
  final double? lat;
  final double? lon;

  /// Точность точки — `qc_geo` DaData: 0 — дом, 1 — ближайший дом, 2 —
  /// улица, 3 — населённый пункт, 4 — город, 5 — не определено. null —
  /// адрес введён руками и точка — центр города. Только сторонам заказа.
  final int? addressPrecision;

  /// Точка — сам дом, по ней можно строить маршрут. Иначе маршрут — по
  /// тексту адреса: центр города увёл бы не туда.
  bool get hasExactPoint =>
      lat != null && lon != null && (addressPrecision ?? 9) <= 1;

  /// «Химки, ул. Ленина, 5». У осмотров до разделения города и адреса
  /// город уже стоит в начале address — не повторяем его.
  String? get fullAddress {
    final street = address;
    if (street == null || street.isEmpty) return null;
    final city = cities.isEmpty ? null : cities.first;
    if (city == null || street.toLowerCase().startsWith(city.toLowerCase())) {
      return street;
    }
    return '$city, $street';
  }

  final DateTime? inspectOn;
  final TimeSlot? timeSlot;

  /// «16:00» — только когда timeSlot == TimeSlot.exact.
  final String? inspectTime;
  final String? listingUrl;

  /// Хост ссылки без www./m. и название площадки («Авито») — считает сервер;
  /// у чужого сайта [listingSite] null, у старой не-ссылки оба null.
  final String? listingHost;
  final String? listingSite;

  /// Объявление у заказа есть. Ссылку ([listingUrl], [listingHost]) сервер
  /// отдаёт только заказчику и выбранному исполнителю — остальные видят
  /// лишь [listingSite] и «откроется после выбора».
  final bool hasListing;

  /// Телефон продавца: бекенд отдаёт его только заказчику и выбранному
  /// исполнителю, остальным ключа в ответе просто нет.
  final String? sellerPhone;

  /// Телефон другой стороны подбора: заказчику — исполнителя, исполнителю —
  /// заказчика. Сервер открывает его с выбора исполнителя и прячет в
  /// отменённом заказе; у разового осмотра — всегда null
  /// (`Order::counterpartPhoneFor` на бекенде).
  final String? counterpartPhone;

  /// Цена, которую назначил заказчик (у осмотра — точка отсчёта для откликов).
  final int? askingPrice;

  final UserSummary customer;
  final UserSummary? executor;

  /// Заказчику — все отклики, исполнителю — только свой (или пусто):
  /// чужие цены и сообщения сервер не отдаёт.
  final List<OrderResponse> responses;

  final int? _responsesCount;

  /// Отклики в игре — ждут выбора или приняты. Устаревшие после переноса,
  /// отказ, срыв и отклонённые выбрать нельзя: в счётчиках и «от X ₽» их нет.
  List<OrderResponse> get activeResponses =>
      responses.where((r) => r.status.isActive).toList();

  /// Сколько откликов в игре. Считать по `responses.length` нельзя — у
  /// исполнителя там максимум один, а у заказчика есть и неактуальные.
  /// Без ключа в ответе (моки) — по [activeResponses].
  int get responsesCount => _responsesCount ?? activeResponses.length;

  /// Отклик зрителя — сервер отдаёт исполнителю только его (или пусто).
  /// Смысл есть только в ленте исполнителя: заказчик видит все отклики, но
  /// свои заказы в ленту не попадают.
  OrderResponse? get viewerResponse =>
      responses.isEmpty ? null : responses.first;

  /// Отклик зрителя в игре: ждёт выбора или принят.
  bool get hasViewerResponse => viewerResponse?.status.isActive ?? false;

  /// Можно ли откликнуться: отклика нет или он устарел после переноса даты.
  /// Иначе сервер ответит 422 (уже откликался, отказался, сорвал срок).
  bool get canViewerRespond => viewerResponse?.status.allowsNewResponse ?? true;

  /// Подпись кнопки отклика в ленте — по состоянию отклика зрителя.
  String get respondLabel => switch (viewerResponse?.status) {
    null => 'Откликнуться',
    OrderResponseStatus.outdated => 'Откликнуться снова',
    OrderResponseStatus.declined => 'Вы отказались',
    OrderResponseStatus.expired => 'Вы не успели',
    _ => 'Вы откликнулись',
  };

  final List<OrderCar> cars;

  final DateTime? completedAt;

  /// Когда заказ отменили; null — не отменён (или сервер старый).
  final DateTime? cancelledAt;

  /// Когда заказ закрылся — завершён или отменён. По нему «Завершённые»
  /// идут от последнего закрытого (QA 2026-11-05 №7).
  DateTime? get closedAt => completedAt ?? cancelledAt;

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

  /// Сервер разрешает открыть спор прямо сейчас. Правило окна — только на
  /// бекенде (Order::disputeAvailableAt): исполнителю — через сутки без
  /// оплаты, заказчику — через сутки без подтверждения. Локально не считаем.
  final bool canDispute;

  /// С какого момента зрителю откроется спор; null — в этом статусе не
  /// откроется вовсе. По нему подсказка «сможете открыть спор …».
  final DateTime? disputeAvailableAt;

  /// До какого момента исполнитель разового осмотра должен довести его до
  /// «отчёт готов» — конец дня осмотра по времени города. Истечение
  /// отрабатывает сервер.
  final DateTime? executorDeadlineAt;

  /// Почему заказ ждёт решения заказчика ([OrderStatus.awaitingDecision]);
  /// сервер отдаёт только заказчику.
  final DecisionReason? decisionReason;
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

  /// Статус для подписи. У подбора `inspecting` ставится первым осмотром и
  /// назад не возвращается, поэтому «на осмотре» — только пока осмотр идёт,
  /// а между осмотрами — «идёт подбор». Сам статус заказа не меняется: на нём
  /// держатся проверки сервера. Без загруженных машин — как пришло.
  OrderStatus get shownStatus {
    if (isInspection || cars.isEmpty) return status;
    if (status != OrderStatus.sourcing && status != OrderStatus.inspecting) {
      return status;
    }
    return cars.any((c) => c.inspectionStatus == 'in_progress')
        ? OrderStatus.inspecting
        : OrderStatus.sourcing;
  }

  /// Подбор закрыт покупкой, а осмотр другого кандидата ещё идёт —
  /// исполнитель его дозавершает (сервер это пускает). Такой заказ у
  /// исполнителя остаётся в «Активных».
  bool get hasUnfinishedInspection =>
      !isInspection &&
      status == OrderStatus.completed &&
      cars.any((c) => c.inspectionStatus == 'in_progress');

  /// Подпись статуса: у подбора между осмотрами — «идёт подбор · осмотрено 3».
  /// Осмотренной считается машина с завершённым осмотром, не просто добавленная.
  String get statusLabel {
    if (hasUnfinishedInspection) {
      return '${status.labelFor(kind)} · осмотр не завершён';
    }
    final shown = shownStatus;
    if (isInspection || shown != OrderStatus.sourcing) {
      return shown.labelFor(kind);
    }
    final done = cars.where((c) => c.inspectionStatus == 'completed').length;
    return done > 0
        ? '${shown.labelFor(kind)} · осмотрено $done'
        : shown.labelFor(kind);
  }

  /// Вторая строка статус-блока на экране подбора: прогресс осмотров.
  /// null — пояснять нечего.
  String? get statusDetail {
    if (isInspection) return null;
    if (hasUnfinishedInspection) return 'Осмотр кандидата ещё не завершён';
    final done = cars.where((c) => c.inspectionStatus == 'completed').length;
    final inspected =
        'Осмотрено ${counted(done, 'машина', 'машины', 'машин')}';
    return switch (shownStatus) {
      OrderStatus.awaitingExecutor => 'Исполнитель ещё не выбран',
      OrderStatus.sourcing =>
        done > 0 ? inspected : 'Осмотренных машин пока нет',
      OrderStatus.inspecting =>
        done > 0
            ? '$inspected, идёт осмотр следующей'
            : 'Идёт осмотр первой машины',
      OrderStatus.completed => done > 0 ? inspected : null,
      _ => null,
    };
  }

  /// Вердикт завершённого осмотра (у заказа-осмотра машина одна).
  InspectionVerdict? get verdict => cars.isEmpty ? null : cars.first.verdict;

  Order copyWith({
    OrderStatus? status,
    int? price,
    UserSummary? executor,
    String? counterpartPhone,
    List<OrderResponse>? responses,
    int? responsesCount,
    List<OrderCar>? cars,
    Review? review,
    bool? canReview,
    bool? canCancel,
    bool? canDispute,
    DateTime? disputeAvailableAt,
    bool clearDisputeWindow = false,
    DateTime? executorDeadlineAt,
    DateTime? paymentSentAt,
    OrderDispute? dispute,
    Payout? payout,
    ReportSummary? reportSummary,
    DateTime? paymentConfirmedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    // повторное размещение осмотра — новая дата, слот, цена
    DateTime? inspectOn,
    TimeSlot? timeSlot,
    String? inspectTime,
    int? askingPrice,
    // исполнитель снят (отказ или срыв) — null через `executor` не передать
    bool clearExecutor = false,
    // заказ размещён заново — причина ожидания решения больше не актуальна
    bool clearDecision = false,
    // оплата подтверждена: реквизиты и сводку сервер больше не отдаёт
    bool clearPayment = false,
  }) => Order(
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
    lat: lat,
    lon: lon,
    addressPrecision: addressPrecision,
    inspectOn: inspectOn ?? this.inspectOn,
    timeSlot: timeSlot ?? this.timeSlot,
    inspectTime: timeSlot != null ? inspectTime : this.inspectTime,
    listingUrl: listingUrl,
    listingHost: listingHost,
    listingSite: listingSite,
    hasListing: hasListing,
    sellerPhone: sellerPhone,
    counterpartPhone: clearExecutor
        ? null
        : (counterpartPhone ?? this.counterpartPhone),
    askingPrice: askingPrice ?? this.askingPrice,
    customer: customer,
    executor: clearExecutor ? null : (executor ?? this.executor),
    responses: responses ?? this.responses,
    // новый список без числа — считаем по нему, иначе счётчик устареет
    responsesCount:
        responsesCount ?? (responses != null ? null : _responsesCount),
    cars: cars ?? this.cars,
    completedAt: completedAt ?? this.completedAt,
    cancelledAt: cancelledAt ?? this.cancelledAt,
    review: review ?? this.review,
    canReview: canReview ?? this.canReview,
    canCancel: canCancel ?? this.canCancel,
    canDispute: clearDisputeWindow ? false : (canDispute ?? this.canDispute),
    disputeAvailableAt: clearDisputeWindow
        ? null
        : (disputeAvailableAt ?? this.disputeAvailableAt),
    executorDeadlineAt: clearExecutor
        ? null
        : (executorDeadlineAt ?? this.executorDeadlineAt),
    decisionReason: clearDecision ? null : decisionReason,
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
    lat: (json['lat'] as num?)?.toDouble(),
    lon: (json['lon'] as num?)?.toDouble(),
    addressPrecision: json['address_precision'] as int?,
    // с бекенда приходит 'Y-m-d' — DateTime.parse даёт локальную полночь
    inspectOn: json['inspect_on'] != null
        ? DateTime.parse(json['inspect_on'] as String)
        : null,
    timeSlot: timeSlotFromApi(json['time_slot'] as String?),
    inspectTime: json['inspect_time'] as String?,
    listingUrl: json['listing_url'] as String?,
    listingHost: json['listing_host'] as String?,
    listingSite: json['listing_site'] as String?,
    // старый бекенд поля не знает — тогда объявление есть, если пришла ссылка
    hasListing: json['has_listing'] as bool? ?? json['listing_url'] != null,
    sellerPhone: json['seller_phone'] as String?,
    counterpartPhone: json['counterpart_phone'] as String?,
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
    cancelledAt: json['cancelled_at'] != null
        ? DateTime.parse(json['cancelled_at'] as String).toLocal()
        : null,
    review: json['review'] != null
        ? Review.fromJson(json['review'] as Map<String, dynamic>)
        : null,
    canReview: json['can_review'] as bool? ?? false,
    canCancel: json['can_cancel'] as bool? ?? false,
    canDispute: json['can_dispute'] as bool? ?? false,
    disputeAvailableAt: _date(json['dispute_available_at']),
    executorDeadlineAt: _date(json['executor_deadline_at']),
    decisionReason: switch (json['decision_reason']) {
      'missed' => DecisionReason.missed,
      'date_passed' => DecisionReason.datePassed,
      _ => null,
    },
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
