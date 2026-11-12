import 'package:auto_podbor_mobile/data/address_repository.dart';
import 'package:auto_podbor_mobile/data/car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/city_repository.dart';
import 'package:auto_podbor_mobile/data/config_repository.dart';
import 'package:auto_podbor_mobile/data/mock_backend.dart';
import 'package:auto_podbor_mobile/data/mock_car_catalog_repository.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_config_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/data/mock_payment_repository.dart';
import 'package:auto_podbor_mobile/data/mock_review_repository.dart';
import 'package:auto_podbor_mobile/data/mock_vin_report_repository.dart';
import 'package:auto_podbor_mobile/data/order_repository.dart';
import 'package:auto_podbor_mobile/data/payment_repository.dart';
import 'package:auto_podbor_mobile/data/review_repository.dart';
import 'package:auto_podbor_mobile/data/vin_report_repository.dart';
import 'package:auto_podbor_mobile/state/city_locator.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';

/// Стор на моках (ревью №39). Заказы — `orders` (по умолчанию общая
/// фикстура), остальные репозитории — моки над тем же [MockBackend], что у
/// `orders`: оплата размещения публикует заказ, как на сервере. Свой мок
/// любого домена — параметром.
OrderStore mockStore({
  OrderRepository? orders,
  MockBackend? backend,
  CarCatalogRepository? catalog,
  CityRepository? cities,
  CityLocator? locator,
  AddressRepository? addresses,
  ReviewRepository? reviews,
  VinReportRepository? vinReports,
  PaymentRepository? payments,
  ConfigRepository? config,
}) {
  final repo = orders ?? MockOrderRepository(backend: backend);
  final world =
      backend ?? (repo is MockOrderRepository ? repo.backend : MockBackend());
  return OrderStore(
    repo,
    reviews: reviews ?? MockReviewRepository(world),
    vinReports: vinReports ?? MockVinReportRepository(world),
    payments: payments ?? MockPaymentRepository(world),
    config: config ?? MockConfigRepository(world),
    catalog: catalog ?? MockCarCatalogRepository(),
    cities: cities ?? MockCityRepository(),
    locator: locator,
    addresses: addresses,
  );
}
