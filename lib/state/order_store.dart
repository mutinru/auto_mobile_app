import 'package:flutter/foundation.dart';

import '../data/order_repository.dart';
import '../models/inspection_verdict.dart';
import '../models/order.dart';
import '../models/time_slot.dart';

/// Состояние экранов "Мои заказы" / "Заказы рядом". Список заказа
/// внутри детали (`fetchOrder`) не кешируется здесь намеренно — экран
/// детали сам владеет своей загрузкой, стор хранит только списки.
class OrderStore extends ChangeNotifier {
  OrderStore(this._repository);

  final OrderRepository _repository;

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

  Future<void> loadMyOrders() async {
    _loadingMine = true;
    _mineError = null;
    notifyListeners();
    try {
      _myOrders = await _repository.fetchMyOrders();
    } catch (e) {
      _mineError = e.toString();
    } finally {
      _loadingMine = false;
      notifyListeners();
    }
  }

  /// Загрузка с обработкой ошибки: экран показывает её вместо вечного
  /// спиннера. loadAssignedOrders пока зависает при падении запроса —
  /// чинится отдельно.
  Future<void> loadAvailableOrders() async {
    _loadingAvailable = true;
    _availableError = null;
    notifyListeners();
    try {
      _availableOrders = await _repository.fetchAvailableOrders();
    } catch (e) {
      _availableError = e.toString();
    } finally {
      _loadingAvailable = false;
      notifyListeners();
    }
  }

  Future<void> loadAssignedOrders() async {
    _loadingAssigned = true;
    notifyListeners();
    _assignedOrders = await _repository.fetchAssignedOrders();
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

  Future<Order> respondToOrder(int orderId, {required int proposedPrice, String? message}) async {
    final order = await _repository.respondToOrder(orderId, proposedPrice: proposedPrice, message: message);
    _availableOrders = _availableOrders.where((o) => o.id != orderId).toList();
    notifyListeners();
    return order;
  }

  Future<Order> fetchOrder(int id) => _repository.fetchOrder(id);

  Future<Order> acceptResponse(int orderId, int responseId) async {
    final order = await _repository.acceptResponse(orderId, responseId);
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
