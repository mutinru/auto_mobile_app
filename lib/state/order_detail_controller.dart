import 'package:flutter/foundation.dart';

import '../models/inspection_verdict.dart';
import '../models/library_inspection.dart';
import '../models/order.dart';
import '../models/order_action.dart';
import '../models/order_car.dart';
import '../models/payment.dart';
import '../widgets/api_error.dart';
import 'order_store.dart';

/// Состояние экрана подбора (ревью №16): заказ, загрузка, библиотека и
/// действия. Запросы идут через [OrderStore] — его `replaceOrder` обновляет
/// списки «Моих» и «Взятых». Шторки, подтверждения, снекбары и навигация —
/// у экрана: он спрашивает пользователя и зовёт действие, ошибку действия
/// контроллер пробрасывает. Повтор действия, пока оно идёт, — ничего.
///
/// Кнопки — только по `Order.actions` с сервера; контроллер правил не считает,
/// кроме роли зрителя до загрузки ([viewerIsCustomer]).
class OrderDetailController extends ChangeNotifier {
  OrderDetailController(
    this.store, {
    required this.orderId,
    required bool viewerIsCustomerHint,
  }) : _viewerHint = viewerIsCustomerHint;

  final OrderStore store;
  final int orderId;
  final bool _viewerHint;

  Order? _order;
  bool _loading = true;
  String? _error;
  InspectionLibraryPage? _library;

  bool _accepting = false;
  bool _completing = false;
  bool _cancelling = false;
  bool _attaching = false;
  bool _purchaseBusy = false;
  bool _releasing = false;
  bool _payingPlacement = false;
  bool _reposting = false;
  bool _disposed = false;

  Order? get order => _order;
  bool get loading => _loading;
  String? get error => _error;

  /// Свои готовые осмотры подборщика для этого подбора; null — не положено
  /// или не загрузилось (кнопки тогда нет: это не главное на экране).
  InspectionLibraryPage? get library => _library;

  bool get accepting => _accepting;
  bool get completing => _completing;
  bool get cancelling => _cancelling;
  bool get attaching => _attaching;

  /// Сообщение о покупке, ответ «нет» или смена купленной машины.
  bool get purchaseBusy => _purchaseBusy;

  /// Идёт отказ исполнителя от подбора.
  bool get releasing => _releasing;

  /// Идёт оплата размещения подбора.
  bool get payingPlacement => _payingPlacement;

  /// Идёт повторное размещение после отказа исполнителя.
  bool get reposting => _reposting;

  /// Идёт загрузка или действие: опрос (AutoRefresh) их результат не затрёт.
  bool get busy =>
      _loading ||
      _accepting ||
      _completing ||
      _cancelling ||
      _attaching ||
      _purchaseBusy ||
      _payingPlacement ||
      _reposting;

  /// Заказчик ли смотрит (ревью №31): роль — из загруженного заказа
  /// (`viewer_role`), подсказка экрана — только до загрузки и для мока, где
  /// роли нет.
  bool get viewerIsCustomer => switch (_order?.viewerRole) {
    ViewerRole.customer => true,
    ViewerRole.executor => false,
    null => _viewerHint,
  };

  /// Заводить кандидатов (и брать из библиотеки) — по правилу сервера
  /// (`actions.add_candidate`): назначенный исполнитель идущего подбора.
  bool canAddCandidates(Order order) =>
      !viewerIsCustomer && order.can(OrderAction.addCandidate);

  /// Отметить покупку — по правилу сервера (`actions.complete`): заказчик,
  /// подбор идёт, есть кандидат с осмотром.
  bool canCompletePurchase(Order order) =>
      viewerIsCustomer && order.can(OrderAction.complete);

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Первая загрузка и «Повторить»: спиннер и ошибка — в состоянии. Без
  /// finally любая ошибка (сеть, 500) оставляла карточку на вечном спиннере.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final order = await store.fetchOrder(orderId);
      _order = order;
      notifyListeners();
      _loadLibrary(order);
    } catch (e) {
      _error = apiErrorText(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Тихое перечитывание (AutoRefresh): без спиннера, ошибку бросает.
  Future<void> refresh() async {
    final before = _order;
    final order = await store.fetchOrder(orderId);
    // пока ждали, заказ подменило действие — его ответ свежее
    if (_disposed || busy || !identical(_order, before)) return;
    _order = order;
    _error = null;
    notifyListeners();
    store.replaceOrder(order);
    _loadLibrary(order);
  }

  /// Библиотека осмотров — тихо, без спиннера: сбой лишь прячет кнопку.
  /// Что в неё попадает, решает сервер — список не фильтруем.
  Future<void> _loadLibrary(Order order) async {
    if (!canAddCandidates(order)) {
      if (_library != null) {
        _library = null;
        notifyListeners();
      }
      return;
    }
    try {
      _library = await store.fetchInspectionLibrary(order.id);
    } catch (_) {
      _library = null;
    }
    notifyListeners();
  }

  /// Принять отклик и перечитать заказ.
  Future<void> accept(int responseId) => _guarded(
    () => _accepting,
    (v) => _accepting = v,
    () async {
      await store.acceptResponse(orderId, responseId);
      await load();
    },
  );

  /// Покупка закрывает подбор; заказ — из ответа сервера, и в нём сразу
  /// can_review, так что блок отзыва появится без перезагрузки.
  Future<void> completePurchase(int carId) => _guarded(
    () => _completing,
    (v) => _completing = v,
    () async => _set(await store.completeSelection(orderId, carId: carId)),
  );

  /// Исполнитель: «заказчик купил эту машину». Заказ не закрывается —
  /// ждём ответа заказчика (purchaseReport в ответе сервера).
  Future<void> reportPurchase(int carId) =>
      _purchase(() => store.reportPurchase(orderId, carId: carId));

  /// Заказчик: «нет, не покупал» на сообщение исполнителя.
  Future<void> declinePurchaseReport() =>
      _purchase(() => store.declinePurchaseReport(orderId));

  /// Заказчик ошибся с купленной машиной — пока сервер пускает.
  Future<void> changePurchase(int carId) =>
      _purchase(() => store.changePurchase(orderId, carId: carId));

  Future<void> _purchase(Future<Order> Function() action) => _guarded(
    () => _purchaseBusy,
    (v) => _purchaseBusy = v,
    () async => _set(await action()),
  );

  /// Исполнитель отказывается от подбора — заказ уходит из «Взятых»
  /// (экран после этого закрывается).
  Future<void> release() => _guarded(
    () => _releasing,
    (v) => _releasing = v,
    () => store.declineOrder(orderId),
  );

  /// Оплатить размещение: начатая оплата — та же, иначе сервер заведёт
  /// новую. Саму оплату проводит экран (`runPayment` — ему нужен context),
  /// итог — заказ с сервера: оплачен — он уже в ленте исполнителей.
  Future<void> payPlacement(
    Future<void> Function(Payment payment) runPayment,
  ) => _guarded(
    () => _payingPlacement,
    (v) => _payingPlacement = v,
    () async {
      final current = _order;
      final payment =
          current?.pendingPayment ??
          (await store.payPlacement(orderId)).pendingPayment;
      if (payment != null) await runPayment(payment);
      final updated = await store.fetchOrder(orderId);
      store.replaceOrder(updated);
      _set(updated);
    },
  );

  /// Исполнитель отказался — заказчик размещает подбор заново.
  Future<void> repost() => _guarded(
    () => _reposting,
    (v) => _reposting = v,
    () async => _set(await store.repostSelection(orderId)),
  );

  /// Отменить можно, пока сервер отдаёт canCancel; заказ — из ответа.
  Future<void> cancel() => _guarded(
    () => _cancelling,
    (v) => _cancelling = v,
    () async => _set(await store.cancelOrder(orderId)),
  );

  /// Свой готовый осмотр — кандидатом. Заказ перечитываем, кандидат
  /// приходит с сервера; при отказе — перечитываем и библиотеку: правило у
  /// сервера, список мог устареть.
  Future<void> attachFromLibrary(int inspectionId) => _guarded(
    () => _attaching,
    (v) => _attaching = v,
    () async {
      try {
        await store.attachFromLibrary(orderId, inspectionId);
        await load();
      } catch (_) {
        if (_order case final order?) await _loadLibrary(order);
        rethrow;
      }
    },
  );

  /// Итог осмотра кандидата: вердикт и комментарий. Заказ остаётся в поиске.
  Future<void> completeCandidate(
    OrderCar car,
    InspectionVerdict verdict,
    String? comment,
  ) async => _set(
    await store.completeCandidate(
      orderId,
      car.id,
      verdict: verdict,
      comment: comment,
    ),
  );

  /// Машина с новым телефоном продавца — из ответа сервера (шторка правки
  /// сама зовёт [OrderStore.updateCarSellerPhone]).
  void applyCar(OrderCar updated) {
    final current = _order;
    if (current == null) return;
    final next = current.copyWith(
      cars: [for (final c in current.cars) c.id == updated.id ? updated : c],
    );
    _order = next;
    notifyListeners();
    store.replaceOrder(next);
  }

  /// Новый отзыв или правка; заказ — из ответа сервера, как и рейтинг.
  Future<void> submitReview(Order order, int rating, String? text) async =>
      _set(
        order.review == null
            ? await store.leaveReview(order.id, rating: rating, text: text)
            : await store.updateReview(order.id, rating: rating, text: text),
      );

  void _set(Order order) {
    _order = order;
    notifyListeners();
  }

  /// Действие под флагом: повтор, пока идёт, — ничего; ошибку бросает.
  Future<void> _guarded(
    bool Function() flag,
    void Function(bool) setFlag,
    Future<void> Function() action,
  ) async {
    if (flag()) return;
    setFlag(true);
    notifyListeners();
    try {
      await action();
    } finally {
      setFlag(false);
      notifyListeners();
    }
  }
}
