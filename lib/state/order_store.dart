import 'dart:async';

import 'paged_orders.dart';
import 'package:flutter/foundation.dart';

import '../data/address_repository.dart';
import '../data/car_catalog_repository.dart';
import '../data/city_repository.dart';
import '../data/config_repository.dart';
import '../data/order_repository.dart';
import '../data/payment_repository.dart';
import '../data/review_repository.dart';
import '../data/vin_report_repository.dart';
import '../models/available_page.dart';
import '../models/inspection_verdict.dart';
import '../models/library_inspection.dart';
import '../models/nearby_filter.dart';
import '../models/order.dart';
import '../models/order_car.dart';
import '../models/payout.dart';
import '../models/time_slot.dart';
import '../widgets/api_error.dart';
import 'city_locator.dart';

/// Состояние экранов "Мои заказы" / "Заказы рядом". Список заказа
/// внутри детали (`fetchOrder`) не кешируется здесь намеренно — экран
/// детали сам владеет своей загрузкой, стор хранит только списки.
class OrderStore extends ChangeNotifier {
  OrderStore(
    this._repository, {
    required this.reviews,
    required this.vinReports,
    required this.payments,
    required this.config,
    required this.catalog,
    required this.cities,
    this.locator,
    this.addresses,
  });

  final OrderRepository _repository;

  /// Узкие репозитории сессии (ревью №39) — экраны берут свой, а не весь
  /// [repository]: отзывы исполнителя, отчёты по VIN, платежи, настройки.
  final ReviewRepository reviews;
  final VinReportRepository vinReports;
  final PaymentRepository payments;
  final ConfigRepository config;

  /// Справочник марок и моделей для форм заказа. Один на приложение
  /// (см. main.dart): кеш справочника живёт дольше отдельного стора.
  final CarCatalogRepository catalog;

  /// Справочник городов — тоже один на приложение.
  final CityRepository cities;

  /// Город по геопозиции. null — без автоопределения (виджет-тесты).
  final CityLocator? locator;

  /// Подсказки адреса осмотра. null — поле адреса без подсказок.
  final AddressRepository? addresses;

  /// Нужен экранам, которые заводят кандидата и стартуют осмотр.
  OrderRepository get repository => _repository;

  List<Order> _myOrders = const [];

  /// «Мои заказы» → «Завершённые»: страницами, грузятся при открытии вкладки.
  late final PagedOrders myFinished = PagedOrders(
    (page) => _repository.fetchMyFinishedOrders(page: page),
  )..addListener(notifyListeners);

  /// «Взятые заказы» → «Завершённые».
  late final PagedOrders assignedFinished = PagedOrders(
    (page) => _repository.fetchAssignedFinishedOrders(page: page),
  )..addListener(notifyListeners);

  List<Order> _availableOrders = const [];
  List<Order> _assignedOrders = const [];
  bool _loadingMine = false;
  bool _loadingAvailable = false;
  bool _loadingAssigned = false;
  String? _availableError;
  String? _mineError;
  String? _assignedError;

  List<Order> get myOrders => List.unmodifiable(_myOrders);
  List<Order> get availableOrders => List.unmodifiable(_availableOrders);
  bool get isLoadingMine => _loadingMine;
  bool get isLoadingAvailable => _loadingAvailable;

  /// Текст ошибки последней загрузки свободных заказов (null — всё хорошо).
  String? get availableError => _availableError;

  /// То же для «Моих заказов».
  String? get mineError => _mineError;
  List<Order> get assignedOrders => List.unmodifiable(_assignedOrders);
  bool get isLoadingAssigned => _loadingAssigned;

  /// То же для «Взятых заказов».
  String? get assignedError => _assignedError;

  /// Номер запроса «Моих заказов»: ответ, обогнанный более новым запросом,
  /// отбрасываем — иначе опрос мог бы вернуть список назад.
  int _mineGeneration = 0;

  /// Первая загрузка и «Повторить»: флаг загрузки и ошибка — в состоянии.
  /// Уже загруженный список ошибка не стирает.
  Future<void> loadMyOrders() async {
    final generation = ++_mineGeneration;
    _loadingMine = true;
    _mineError = null;
    _notifyStarted();
    try {
      final orders = await _repository.fetchMyOrders();
      if (generation == _mineGeneration) _myOrders = orders;
    } catch (e) {
      if (generation == _mineGeneration) _mineError = apiErrorText(e);
    } finally {
      if (generation == _mineGeneration) _loadingMine = false;
      notifyListeners();
    }
  }

  /// Тихое перечитывание «Моих заказов» (автообновление, потягивание): без
  /// флага загрузки, ошибку бросает и состояние не трогает.
  Future<void> refreshMyOrders() async {
    final generation = ++_mineGeneration;
    final orders = await _repository.fetchMyOrders();
    if (generation != _mineGeneration) return;
    _myOrders = orders;
    _mineError = null;
    _loadingMine = false;
    notifyListeners();
  }

  // --- «Заказы рядом»: фильтрует и листает сервер ---

  NearbyFilter _availableFilter = const NearbyFilter();
  bool _availableFew = false;
  int _availablePage = 0;
  bool _availableHasMore = false;
  bool _loadingMoreAvailable = false;
  String? _availableMoreError;
  int _availableTotal = 0;
  int _availableAll = 0;
  List<Facet> _cityFacets = const [];
  List<Facet> _brandFacets = const [];

  /// Номер запроса ленты: ответ на устаревший фильтр (пользователь успел
  /// сменить его) отбрасываем, а не подмешиваем.
  int _availableGeneration = 0;

  bool get hasMoreAvailable => _availableHasMore;

  /// Растёт с каждой принятой страницей — ключ подвала подгрузки: после
  /// перезагрузки список той же длины, а подвал должен сработать заново.
  int get availableVersion => _availableVersion;
  int _availableVersion = 0;
  bool get isLoadingMoreAvailable => _loadingMoreAvailable;

  /// Ошибка подгрузки следующей страницы — подвал с «Повторить», а не
  /// экран ошибки: загруженное остаётся на месте.
  String? get availableMoreError => _availableMoreError;

  /// Заказов под фильтром на всех страницах.
  int get availableTotal => _availableTotal;

  /// Свободных без фильтров.
  int get availableAll => _availableAll;

  /// Варианты шторки — по всем свободным, с первой страницы.
  List<Facet> get cityFacets => _cityFacets;
  List<Facet> get brandFacets => _brandFacets;

  /// Первая страница ленты. Без аргументов — с прошлым фильтром
  /// («Повторить», обновление жестом, возврат из уведомлений). Пока идёт
  /// загрузка, прежний список остаётся на экране.
  Future<void> loadAvailableOrders({
    NearbyFilter? filter,
    bool? fewResponses,
  }) async {
    _availableFilter = filter ?? _availableFilter;
    _availableFew = fewResponses ?? _availableFew;
    final generation = ++_availableGeneration;
    _loadingAvailable = true;
    _loadingMoreAvailable = false;
    _availableError = null;
    _availableMoreError = null;
    _notifyStarted();
    try {
      final page = await _repository.fetchAvailableOrders(
        filter: _availableFilter,
        fewResponses: _availableFew,
      );
      if (generation != _availableGeneration) return;
      _availableOrders = page.items;
      _applyAvailablePage(page);
    } catch (e) {
      if (generation != _availableGeneration) return;
      _availableError = apiErrorText(e);
    } finally {
      if (generation == _availableGeneration) {
        _loadingAvailable = false;
        notifyListeners();
      }
    }
  }

  /// Следующая страница — когда подвал списка показался на экране.
  Future<void> loadMoreAvailable() async {
    if (!_availableHasMore || _loadingAvailable || _loadingMoreAvailable) {
      return;
    }
    final generation = _availableGeneration;
    _loadingMoreAvailable = true;
    _availableMoreError = null;
    notifyListeners();
    try {
      final page = await _repository.fetchAvailableOrders(
        filter: _availableFilter,
        fewResponses: _availableFew,
        page: _availablePage + 1,
      );
      if (generation != _availableGeneration) return;
      // новые заказы сдвигают страницы — повтор с прошлой отбрасываем
      final seen = {for (final o in _availableOrders) o.id};
      _availableOrders = [
        ..._availableOrders,
        ...page.items.where((o) => seen.add(o.id)),
      ];
      _applyAvailablePage(page);
    } catch (e) {
      if (generation != _availableGeneration) return;
      _availableMoreError = apiErrorText(e);
    } finally {
      if (generation == _availableGeneration) {
        _loadingMoreAvailable = false;
        notifyListeners();
      }
    }
  }

  void _applyAvailablePage(AvailablePage page) {
    _availableVersion++;
    _availablePage = page.page;
    _availableHasMore = page.hasMore;
    _availableTotal = page.total;
    _availableAll = page.all;
    _cityFacets = page.cityFacets ?? _cityFacets;
    _brandFacets = page.brandFacets ?? _brandFacets;
  }

  /// Счётчик шторки: сколько заказов покажет [filter] — без загрузки.
  Future<int> countAvailableOrders(NearbyFilter filter, {bool? fewResponses}) =>
      _repository.countAvailableOrders(
        filter: filter,
        fewResponses: fewResponses ?? _availableFew,
      );

  /// Номер запроса «Взятых заказов» — как [_mineGeneration].
  int _assignedGeneration = 0;

  /// Как [loadMyOrders], для «Взятых заказов».
  Future<void> loadAssignedOrders() async {
    final generation = ++_assignedGeneration;
    _loadingAssigned = true;
    _assignedError = null;
    _notifyStarted();
    try {
      final orders = await _repository.fetchAssignedOrders();
      if (generation == _assignedGeneration) _assignedOrders = orders;
    } catch (e) {
      if (generation == _assignedGeneration) {
        _assignedError = apiErrorText(e);
      }
    } finally {
      if (generation == _assignedGeneration) _loadingAssigned = false;
      notifyListeners();
    }
  }

  /// Как [refreshMyOrders], для «Взятых заказов».
  Future<void> refreshAssignedOrders() async {
    final generation = ++_assignedGeneration;
    final orders = await _repository.fetchAssignedOrders();
    if (generation != _assignedGeneration) return;
    _assignedOrders = orders;
    _assignedError = null;
    _loadingAssigned = false;
    notifyListeners();
  }

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
    final order = await _repository.createOrder(
      brand: brand,
      model: model,
      yearFrom: yearFrom,
      mileageTo: mileageTo,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      cities: cities,
      requirements: requirements,
      comment: comment,
    );
    _mineGeneration++; // ответ на запрос, ушедший раньше, заказа ещё не знает
    _loadingMine = false;
    _myOrders = [order, ..._myOrders];
    notifyListeners();
    return order;
  }

  /// Заказ на разовый осмотр (order-types.html, кадр 03).
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
    final order = await _repository.createInspectionOrder(
      brand: brand,
      model: model,
      year: year,
      mileageKm: mileageKm,
      city: city,
      cityId: cityId,
      address: address,
      lat: lat,
      lon: lon,
      addressPrecision: addressPrecision,
      inspectOn: inspectOn,
      timeSlot: timeSlot,
      askingPrice: askingPrice,
      inspectTime: inspectTime,
      vin: vin,
      listingUrl: listingUrl,
      sellerPhone: sellerPhone,
      comment: comment,
    );
    _mineGeneration++; // ответ на запрос, ушедший раньше, заказа ещё не знает
    _loadingMine = false;
    _myOrders = [order, ..._myOrders];
    notifyListeners();
    return order;
  }

  Future<Order> completeInspection(
    int orderId, {
    required InspectionVerdict verdict,
    String? comment,
  }) async {
    final order = await _repository.completeInspection(
      orderId,
      verdict: verdict,
      comment: comment,
    );
    replaceOrder(order);
    return order;
  }

  Future<Order> respondToOrder(
    int orderId, {
    required int proposedPrice,
    String? message,
    Payout? payout,
  }) async {
    final order = await _repository.respondToOrder(
      orderId,
      proposedPrice: proposedPrice,
      message: message,
      payout: payout,
    );
    // заказ остаётся в ленте с ответом сервера: «Ваш отклик», счётчик +1
    // и неактивная кнопка — так же, как после перезагрузки ленты
    _availableOrders = [
      for (final o in _availableOrders) o.id == orderId ? order : o,
    ];
    notifyListeners();
    return order;
  }

  Future<Order> fetchOrder(int id) => _repository.fetchOrder(id);

  Future<Order> acceptResponse(int orderId, int responseId) async {
    final order = await _repository.acceptResponse(orderId, responseId);
    replaceOrder(order);
    return order;
  }

  /// Вердикт кандидата и его статус — из ответа сервера.
  Future<Order> completeCandidate(
    int orderId,
    int carId, {
    required InspectionVerdict verdict,
    String? comment,
  }) => _mutate(
    _repository.completeCandidate(
      orderId,
      carId,
      verdict: verdict,
      comment: comment,
    ),
  );

  /// Исход кандидатов и can_review — из ответа сервера.
  Future<Order> completeSelection(int orderId, {required int carId}) =>
      _mutate(_repository.completeSelection(orderId, carId: carId));

  /// Сообщение исполнителя о покупке — заказ с purchaseReport из ответа.
  Future<Order> reportPurchase(int orderId, {required int carId}) =>
      _mutate(_repository.reportPurchase(orderId, carId: carId));

  Future<Order> declinePurchaseReport(int orderId) =>
      _mutate(_repository.declinePurchaseReport(orderId));

  /// Исходы кандидатов — из ответа сервера, счётчики не меняются.
  Future<Order> changePurchase(int orderId, {required int carId}) =>
      _mutate(_repository.changePurchase(orderId, carId: carId));

  /// Отменённый заказ уезжает в архив списка — статус из ответа сервера.
  /// Новая оплата размещения (прошлая не прошла); заказ — с pendingPayment.
  Future<Order> payPlacement(int orderId) =>
      _mutate(_repository.payPlacement(orderId));

  Future<Order> cancelOrder(int orderId) =>
      _mutate(_repository.cancelOrder(orderId));

  /// Подбор размещён заново после отказа исполнителя — заказ из ответа сервера.
  Future<Order> repostSelection(int orderId) =>
      _mutate(_repository.repostSelection(orderId));

  /// Осмотр размещён заново на новую дату — заказ из ответа сервера.
  Future<Order> repostInspection(
    int orderId, {
    required DateTime inspectOn,
    required TimeSlot timeSlot,
    String? inspectTime,
    int? askingPrice,
  }) => _mutate(
    _repository.repostInspection(
      orderId,
      inspectOn: inspectOn,
      timeSlot: timeSlot,
      inspectTime: inspectTime,
      askingPrice: askingPrice,
    ),
  );

  /// Рейтинг исполнителя и can_review не пересчитываем — берём заказ,
  /// который вернул сервер.
  Future<Order> leaveReview(
    int orderId, {
    required int rating,
    String? text,
  }) async {
    final order = await _repository.leaveReview(
      orderId,
      rating: rating,
      text: text,
    );
    replaceOrder(order);
    return order;
  }

  Future<Order> updateReview(
    int orderId, {
    required int rating,
    String? text,
  }) async {
    final order = await _repository.updateReview(
      orderId,
      rating: rating,
      text: text,
    );
    replaceOrder(order);
    return order;
  }

  /// Исполнитель отказался — заказ уходит из «Взятых».
  Future<Order> declineOrder(int orderId) async {
    final order = await _repository.declineOrder(orderId);
    _assignedGeneration++; // ответ, ушедший раньше, вернул бы заказ назад
    _loadingAssigned = false;
    _assignedOrders = _assignedOrders.where((o) => o.id != orderId).toList();
    replaceOrder(order);
    notifyListeners();
    return order;
  }

  Future<Order> markPaymentSent(int orderId) =>
      _mutate(_repository.markPaymentSent(orderId));

  Future<Order> confirmPayment(int orderId) =>
      _mutate(_repository.confirmPayment(orderId));

  Future<Order> openDispute(int orderId, {required String reason}) =>
      _mutate(_repository.openDispute(orderId, reason: reason));

  /// Статус и поля оплаты — с сервера, локально не вычисляем.
  Future<Order> _mutate(Future<Order> request) async {
    final order = await request;
    replaceOrder(order);
    return order;
  }

  /// Свежий заказ с сервера — в списки, где он есть (мутация, перечитывание
  /// открытой детали).
  /// Телефон продавца кандидата (заметка подборщика); машина — из ответа
  /// сервера, заказ в списках обновляет экран через [replaceOrder].
  Future<OrderCar> updateCarSellerPhone(
    int orderId,
    int carId,
    String? sellerPhone,
  ) => _repository.updateCarSellerPhone(orderId, carId, sellerPhone);

  /// Библиотека осмотров исполнителя для этого подбора — с сервера.
  Future<InspectionLibraryPage> fetchInspectionLibrary(int orderId) =>
      _repository.fetchInspectionLibrary(orderId);

  /// Прикрепить готовый осмотр; заказ экран перечитывает сам.
  Future<OrderCar> attachFromLibrary(int orderId, int inspectionId) =>
      _repository.attachFromLibrary(orderId, inspectionId);

  /// Стор живёт сессию входа ([OrderSession]) и освобождается при выходе,
  /// пока экраны ещё уходят, а их запросы в пути: ответ после этого
  /// никого не уведомляет (иначе assert ChangeNotifier).
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  /// Начало загрузки. Флаг уже стоит, и экран, который строится сейчас, его
  /// увидит; остальным слушателям сообщаем после кадра. Загрузки зовут из
  /// `initState`, а стор общий на сессию: синхронное уведомление пометило бы
  /// для перестройки список под новым экраном посреди сборки кадра —
  /// assert «markNeedsBuild() called during build».
  void _notifyStarted() => scheduleMicrotask(notifyListeners);

  @override
  void dispose() {
    _disposed = true;
    myFinished.dispose();
    assignedFinished.dispose();
    super.dispose();
  }

  void replaceOrder(Order order) {
    final mine = _myOrders.indexWhere((o) => o.id == order.id);
    if (mine != -1) _myOrders = [..._myOrders]..[mine] = order;
    final assigned = _assignedOrders.indexWhere((o) => o.id == order.id);
    if (assigned != -1) {
      _assignedOrders = [..._assignedOrders]..[assigned] = order;
    }
    if (mine != -1 || assigned != -1) notifyListeners();
    myFinished.replace(order);
    assignedFinished.replace(order);
  }
}
