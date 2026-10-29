import 'package:flutter/foundation.dart';

import '../data/car_catalog_repository.dart';
import '../data/city_repository.dart';
import '../data/order_repository.dart';
import '../models/inspection_verdict.dart';
import '../models/order.dart';
import '../models/payout.dart';
import '../models/time_slot.dart';
import '../widgets/api_error.dart';
import 'city_locator.dart';

/// Состояние экранов "Мои заказы" / "Заказы рядом". Список заказа
/// внутри детали (`fetchOrder`) не кешируется здесь намеренно — экран
/// детали сам владеет своей загрузкой, стор хранит только списки.
class OrderStore extends ChangeNotifier {
  OrderStore(this._repository, {required this.catalog, required this.cities, this.locator});

  final OrderRepository _repository;

  /// Справочник марок и моделей для форм заказа. Один на приложение
  /// (см. main.dart): кеш справочника живёт дольше отдельного стора.
  final CarCatalogRepository catalog;

  /// Справочник городов — тоже один на приложение.
  final CityRepository cities;

  /// Город по геопозиции. null — без автоопределения (виджет-тесты).
  final CityLocator? locator;

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

  /// Загрузка с обработкой ошибки: экран показывает её вместо вечного
  /// спиннера.
  Future<void> loadAvailableOrders() async {
    _loadingAvailable = true;
    _availableError = null;
    notifyListeners();
    try {
      _availableOrders = await _repository.fetchAvailableOrders();
    } catch (e) {
      _availableError = apiErrorText(e);
    } finally {
      _loadingAvailable = false;
      notifyListeners();
    }
  }

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
    final order = await _repository.createInspectionOrder(
      brand: brand,
      model: model,
      year: year,
      mileageKm: mileageKm,
      address: address,
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
    _replaceInLists(order);
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
    _replaceInLists(order);
    return order;
  }

  /// Исход кандидатов и can_review — из ответа сервера.
  Future<Order> completeSelection(int orderId, {required int carId}) =>
      _mutate(_repository.completeSelection(orderId, carId: carId));

  /// Отменённый заказ уезжает в архив списка — статус из ответа сервера.
  Future<Order> cancelOrder(int orderId) => _mutate(_repository.cancelOrder(orderId));

  /// Рейтинг исполнителя и can_review не пересчитываем — берём заказ,
  /// который вернул сервер.
  Future<Order> leaveReview(int orderId, {required int rating, String? text}) async {
    final order = await _repository.leaveReview(orderId, rating: rating, text: text);
    _replaceInLists(order);
    return order;
  }

  Future<Order> updateReview(int orderId, {required int rating, String? text}) async {
    final order = await _repository.updateReview(orderId, rating: rating, text: text);
    _replaceInLists(order);
    return order;
  }

  /// Исполнитель отказался — заказ уходит из «Взятых».
  Future<Order> declineOrder(int orderId) async {
    final order = await _repository.declineOrder(orderId);
    _assignedOrders = _assignedOrders.where((o) => o.id != orderId).toList();
    _replaceInLists(order);
    notifyListeners();
    return order;
  }

  Future<Order> markPaymentSent(int orderId) => _mutate(_repository.markPaymentSent(orderId));

  Future<Order> confirmPayment(int orderId) => _mutate(_repository.confirmPayment(orderId));

  Future<Order> openDispute(int orderId, {required String reason}) =>
      _mutate(_repository.openDispute(orderId, reason: reason));

  /// Статус и поля оплаты — с сервера, локально не вычисляем.
  Future<Order> _mutate(Future<Order> request) async {
    final order = await request;
    _replaceInLists(order);
    return order;
  }

  void _replaceInLists(Order order) {
    final mine = _myOrders.indexWhere((o) => o.id == order.id);
    if (mine != -1) _myOrders = [..._myOrders]..[mine] = order;
    final assigned = _assignedOrders.indexWhere((o) => o.id == order.id);
    if (assigned != -1) _assignedOrders = [..._assignedOrders]..[assigned] = order;
    if (mine != -1 || assigned != -1) notifyListeners();
  }
}
