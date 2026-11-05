import 'package:flutter/foundation.dart';

import '../data/address_repository.dart';
import '../data/car_catalog_repository.dart';
import '../data/city_repository.dart';
import '../data/order_repository.dart';
import '../models/available_page.dart';
import '../models/inspection_verdict.dart';
import '../models/nearby_filter.dart';
import '../models/order.dart';
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
    required this.catalog,
    required this.cities,
    this.locator,
    this.addresses,
  });

  final OrderRepository _repository;

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

  Future<void> loadMyOrders() async {
    _loadingMine = true;
    _mineError = null;
    notifyListeners();
    try {
      _myOrders = await _repository.fetchMyOrders();
    } catch (e) {
      _mineError = apiErrorText(e);
    } finally {
      _loadingMine = false;
      notifyListeners();
    }
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
    notifyListeners();
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

  Future<void> loadAssignedOrders() async {
    _loadingAssigned = true;
    _assignedError = null;
    notifyListeners();
    try {
      _assignedOrders = await _repository.fetchAssignedOrders();
    } catch (e) {
      _assignedError = apiErrorText(e);
    } finally {
      _loadingAssigned = false;
      notifyListeners();
    }
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

  /// Отменённый заказ уезжает в архив списка — статус из ответа сервера.
  Future<Order> cancelOrder(int orderId) =>
      _mutate(_repository.cancelOrder(orderId));

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
  void replaceOrder(Order order) {
    final mine = _myOrders.indexWhere((o) => o.id == order.id);
    if (mine != -1) _myOrders = [..._myOrders]..[mine] = order;
    final assigned = _assignedOrders.indexWhere((o) => o.id == order.id);
    if (assigned != -1) {
      _assignedOrders = [..._assignedOrders]..[assigned] = order;
    }
    if (mine != -1 || assigned != -1) notifyListeners();
  }
}
