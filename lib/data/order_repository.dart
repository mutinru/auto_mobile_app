import '../models/available_page.dart';
import '../models/inspection_verdict.dart';
import '../models/nearby_filter.dart';
import '../models/order.dart';
import '../models/order_car.dart';
import '../models/payout.dart';
import '../models/review.dart';
import '../models/vin_kind.dart';
import '../models/vin_report.dart';
import '../models/time_slot.dart';

/// Источник данных маркетплейса заказов. Как и InspectionRepository —
/// две реализации: [MockOrderRepository] для UI без бекенда,
/// [ApiOrderRepository] поверх Laravel API (routes/api.php, группа orders).
abstract class OrderRepository {
  Future<List<Order>> fetchMyOrders();

  /// Лента «Заказы рядом»: фильтр, сортировка и страницы — на сервере.
  Future<AvailablePage> fetchAvailableOrders({
    NearbyFilter filter = const NearbyFilter(),
    bool fewResponses = false,
    int page = 1,
  });

  /// Сколько заказов под фильтром — счётчик «Показать N» в шторке.
  Future<int> countAvailableOrders({
    NearbyFilter filter = const NearbyFilter(),
    bool fewResponses = false,
  });

  /// Заказы, где пользователь — назначенный исполнитель.
  Future<List<Order>> fetchAssignedOrders();
  Future<Order> fetchOrder(int id);

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
  });

  /// Разовый осмотр конкретной машины: бекенд заводит заказ и его
  /// единственную Car в одной транзакции (order-types.html, кадр 03).
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
  });

  /// Завершить разовый осмотр вердиктом (исполнитель).
  Future<Order> completeInspection(
    int orderId, {
    required InspectionVerdict verdict,
    String? comment,
  });

  /// [payout] — реквизиты при первом отклике на разовый осмотр: сервер
  /// сохранит их в профиль и дальше не спросит.
  Future<Order> respondToOrder(
    int orderId, {
    required int proposedPrice,
    String? message,
    Payout? payout,
  });

  /// Исполнитель отказывается от разового осмотра (до «отчёт готов»):
  /// заказ возвращается к остальным откликам.
  Future<Order> declineOrder(int orderId);

  /// Заказчик сообщает, что оплатил исполнителю напрямую.
  Future<Order> markPaymentSent(int orderId);

  /// Исполнитель подтверждает оплату — заказчик получает отчёт.
  Future<Order> confirmPayment(int orderId);

  /// Спор об оплате — любая сторона, причина обязательна.
  Future<Order> openDispute(int orderId, {required String reason});

  Future<Order> acceptResponse(int orderId, int responseId);

  /// Исполнитель подбора завершает осмотр кандидата [carId] вердиктом:
  /// осмотр — completed, заказ остаётся в поиске, заказчику — уведомление.
  Future<Order> completeCandidate(
    int orderId,
    int carId, {
    required InspectionVerdict verdict,
    String? comment,
  });

  /// Заказчик закрывает подбор покупкой кандидата [carId]: остальные
  /// кандидаты становятся отклонёнными, заказ — завершённым.
  Future<Order> completeSelection(int orderId, {required int carId});

  /// Заказчик отменяет заказ, пока сервер разрешает (Order.canCancel).
  Future<Order> cancelOrder(int orderId);

  /// Заказчик размещает разовый осмотр заново после срыва или пропущенного
  /// дня ([OrderStatus.awaitingDecision]): новая дата обязательна, цену
  /// можно поменять. Старые отклики сервер отклоняет.
  Future<Order> repostInspection(
    int orderId, {
    required DateTime inspectOn,
    required TimeSlot timeSlot,
    String? inspectTime,
    int? askingPrice,
  });

  /// Отзыв заказчика об исполнителе по завершённому заказу. Возвращает
  /// заказ целиком: рейтинг исполнителя и can_review пересчитал сервер.
  Future<Order> leaveReview(int orderId, {required int rating, String? text});

  /// Правка отзыва — сервер разрешает её 24 часа после создания.
  Future<Order> updateReview(int orderId, {required int rating, String? text});

  /// Отзывы об исполнителе, свежие сверху; [page] с 1.
  Future<ReviewPage> fetchExecutorReviews(int userId, {int page = 1});

  /// Завести кандидата подбора — исполнитель нашёл вариант и начинает его
  /// осмотр. Сервер создаёт машину и осмотр со всеми пунктами одной
  /// транзакцией: у вернувшейся машины уже есть [OrderCar.inspectionId].
  /// [vin] — снят с таблички вместе с фото; в одном подборе не повторяется.
  /// [odometer] — пробег по приборке с её фото. [sellerPhone] (+7XXXXXXXXXX)
  /// — заметка подборщика для себя, заказчику сервер её не отдаёт.
  Future<OrderCar> addCar(
    int orderId, {
    required String brand,
    required String model,
    required int year,
    required CapturedVin vin,
    required CapturedOdometer odometer,
    String? licensePlate,
    String? sellerPhone,
  });

  /// Телефон продавца кандидата — поменять или стереть (null). Только
  /// назначенный подборщик; возвращает машину с новым номером.
  Future<OrderCar> updateCarSellerPhone(
    int orderId,
    int carId,
    String? sellerPhone,
  );

  /// Начать разовый осмотр — бекенд сам создаёт все пункты (кузов и extra).
  /// [vin] с фото таблички и [odometer] с фото приборки заменяют то, что
  /// указал заказчик. У подбора отдельного старта нет — осмотр кандидата
  /// создаёт [addCar]. Возвращает id созданного осмотра.
  Future<int> startInspection(
    int orderId,
    int carId, {
    required CapturedVin vin,
    required CapturedOdometer odometer,
  });

  /// Готовые отчёты по VIN (или номеру кузова): тизер без вердикта и цена.
  /// Сервер считает разные VIN — не больше 15 в сутки, сверх — 429.
  Future<VinReportCheck> checkVinReports(String vin);

  /// Купить пакет готовых отчётов по VIN. Пока эквайринга нет, оплата
  /// проходит сразу; позже ответ может прийти неоплаченным со ссылкой
  /// подтверждения ([VinReportPurchase.confirmationUrl]).
  Future<VinReportPurchase> purchaseVinReport(String vin);

  /// Оплаченные пакеты заказчика, свежие сверху.
  Future<List<VinReportPurchase>> fetchVinReportPurchases();

  Future<VinReportPurchase> fetchVinReportPurchase(int id);
}
