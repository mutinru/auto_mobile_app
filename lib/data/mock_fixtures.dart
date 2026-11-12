import '../models/inspection_verdict.dart';
import '../models/order.dart';
import '../models/order_action.dart';
import '../models/order_car.dart';
import '../models/order_kind.dart';
import '../models/order_response.dart';
import '../models/order_response_status.dart';
import '../models/order_status.dart';
import '../models/payout.dart';
import '../models/time_slot.dart';
import '../models/user_summary.dart';
import '../models/vin_report.dart';

/// Данные мока (ревью №39): пользователи, общая фикстура заказов, отчёты
/// по VIN. Поведение — в моках репозиториев над [MockBackend].
abstract final class MockFixtures {
  /// Реквизиты, которые мок отдаёт заказчику в момент оплаты.
  static const payout = Payout(
    card: '2200700000000009',
    phone: '+79000000001',
    bank: 'Т-Банк',
  );

  /// VIN, по которому в моке есть готовые отчёты.
  static const reportVin = 'XW8ZZZ61ZKG100111';

  /// Готовые отчёты по [reportVin] — два осмотра.
  static final reportItems = [
    VinReportItem(
      date: DateTime(2026, 10, 20),
      city: 'Москва',
      mileageKm: 112000,
    ),
    VinReportItem(date: DateTime(2026, 9, 2), city: 'Химки', mileageKm: 98000),
  ];

  static const me = UserSummary(id: 1, name: 'Андрей С.');

  // сводка исполнителей — чтобы в откликах были и рейтинг, и «новый»
  static const maxim = UserSummary(
    id: 10,
    name: 'Максим К.',
    rating: 4.9,
    reviewsCount: 12,
    completedOrdersCount: 30,
  );
  static const sergey = UserSummary(
    id: 14,
    name: 'Сергей П.',
    rating: 4.7,
    reviewsCount: 5,
    completedOrdersCount: 8,
  );
  static const oleg = UserSummary(id: 15, name: 'Олег К.');

  /// Общая фикстура заказов всех виджет-тестов.
  static List<Order> orders() => [
    // разовые осмотры (order-types.html, кадры 01 и 05)
    Order(
      id: 2051,
      kind: OrderKind.inspection,
      status: OrderStatus.scheduled,
      brand: 'Kia',
      model: 'Rio',
      yearFrom: 2019,
      mileageTo: 64000,
      customer: me,
      executor: maxim,
      cities: ['Химки'],
      address: 'ул. Ленина, 5',
      inspectOn: DateTime.now().add(const Duration(days: 1)),
      timeSlot: TimeSlot.exact,
      inspectTime: '16:00',
      askingPrice: 4000,
      price: 4000,
      sellerPhone: '+79161234567',
      cars: const [
        OrderCar(
          id: 511,
          brand: 'Kia',
          model: 'Rio',
          year: 2019,
          vinMasked: '—',
          // осмотр не начат: пробег пока только со слов продавца
          customerMileageKm: 64000,
        ),
      ],
    ),
    Order(
      id: 2053,
      kind: OrderKind.inspection,
      status: OrderStatus.awaitingExecutor,
      brand: 'BMW',
      model: 'X3',
      yearFrom: 2017,
      mileageTo: 112000,
      customer: me,
      cities: ['Москва'],
      address: 'Варшавское ш., 170',
      inspectOn: DateTime.now().add(const Duration(days: 3)),
      timeSlot: TimeSlot.day,
      askingPrice: 3500,
      listingUrl: 'https://auto.ru/cars/used/sale/bmw/x3/1120000123',
      listingHost: 'auto.ru',
      listingSite: 'Авто.ру',
      hasListing: true,
      responses: const [
        OrderResponse(
          id: 21,
          status: OrderResponseStatus.pending,
          proposedPrice: 3000,
          executor: sergey,
        ),
        OrderResponse(
          id: 22,
          status: OrderResponseStatus.pending,
          proposedPrice: 3500,
          executor: maxim,
        ),
        OrderResponse(
          id: 23,
          status: OrderResponseStatus.pending,
          proposedPrice: 4500,
          executor: oleg,
        ),
      ],
    ),
    Order(
      id: 2047,
      kind: OrderKind.inspection,
      status: OrderStatus.completed,
      completedAt: DateTime.now().subtract(const Duration(days: 2)),
      actions: const {OrderAction.review},
      brand: 'Hyundai',
      model: 'Creta',
      yearFrom: 2020,
      mileageTo: 71000,
      customer: me,
      executor: maxim,
      cities: ['Мытищи'],
      address: 'ул. Мира, 12',
      inspectOn: DateTime.now().subtract(const Duration(days: 2)),
      timeSlot: TimeSlot.morning,
      askingPrice: 4000,
      price: 4000,
      cars: const [
        OrderCar(
          id: 512,
          brand: 'Hyundai',
          model: 'Creta',
          year: 2020,
          vinMasked: '··· 100077',
          // по одометру больше, чем в объявлении, — плашка расхождения
          mileageKm: 98000,
          customerMileageKm: 71000,
          mileageMismatch: true,
          inspectionId: 90,
          inspectionStatus: 'completed',
          verdict: InspectionVerdict.notRecommended,
          verdictComment: '3 детали перекрашены, замена крыла',
        ),
      ],
    ),
    const Order(
      id: 2041,
      status: OrderStatus.inspecting,
      brand: 'Toyota',
      model: 'Camry',
      yearFrom: 2018,
      budgetMin: 2000000,
      budgetMax: 2400000,
      customer: me,
      executor: maxim,
      price: 12000,
    ),
    const Order(
      id: 2038,
      status: OrderStatus.sourcing,
      brand: 'Kia',
      model: 'Sportage',
      yearFrom: 2021,
      budgetMax: 3100000,
      customer: me,
      executor: UserSummary(id: 11, name: 'Игорь В.'),
      price: 15000,
    ),
    const Order(
      id: 2044,
      status: OrderStatus.awaitingExecutor,
      brand: 'Volkswagen',
      model: 'Tiguan',
      yearFrom: 2019,
      budgetMax: 2000000,
      customer: me,
      responses: [
        OrderResponse(
          id: 1,
          status: OrderResponseStatus.pending,
          proposedPrice: 10000,
          executor: UserSummary(id: 12, name: 'Денис П.'),
        ),
      ],
    ),
  ];
}
