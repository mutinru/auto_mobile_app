import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/location_service.dart';
import 'package:auto_podbor_mobile/data/mock_city_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/models/available_page.dart';
import 'package:auto_podbor_mobile/models/nearby_filter.dart';
import 'package:auto_podbor_mobile/models/order_kind.dart';
import 'package:auto_podbor_mobile/state/city_locator.dart';
import 'package:auto_podbor_mobile/state/nearby_feed_controller.dart';
import 'package:auto_podbor_mobile/state/nearby_filter_store.dart';

import 'support/stores.dart';

/// Мок, который запоминает запросы первой страницы ленты.
class _Recording extends MockOrderRepository {
  final requests = <({NearbyFilter filter, bool few})>[];

  @override
  Future<AvailablePage> fetchAvailableOrders({
    NearbyFilter filter = const NearbyFilter(),
    bool fewResponses = false,
    int page = 1,
  }) {
    if (page == 1) requests.add((filter: filter, few: fewResponses));
    return super.fetchAvailableOrders(
      filter: filter,
      fewResponses: fewResponses,
      page: page,
    );
  }
}

/// GPS, который отвечает по команде теста.
class _GatedHere implements LocationService {
  _GatedHere(this.point);

  final (double, double)? point;
  final gate = Completer<void>();

  @override
  Future<bool> isGranted() async => true;

  @override
  Future<(double, double)?> current() async {
    await gate.future;
    return point;
  }

  @override
  Future<LocationProblem?> problem() async => null;

  @override
  Future<void> openSettings(LocationProblem problem) async {}
}

const _moscow = (55.7558, 37.6173);

/// Ленту листает и фильтрует сервер; контроллер решает, когда и с чем
/// звать `loadAvailableOrders` (ревью №16).
void main() {
  late _Recording repo;

  setUp(() => repo = _Recording());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('смена фильтра — один запрос, тот же фильтр — ни одного', () async {
    final feed = NearbyFeedController(mockStore(orders: repo))..start();
    addTearDown(feed.dispose);
    await settle();
    expect(repo.requests, hasLength(1));

    await feed.filters.set(const NearbyFilter(kind: OrderKind.inspection));
    await settle();
    expect(repo.requests, hasLength(2));
    expect(repo.requests.last.filter.kind, OrderKind.inspection);

    // стор фильтров уведомил, а фильтр тот же — запрос не нужен
    await feed.reload();
    expect(repo.requests, hasLength(2));
  });

  test('«Мало откликов» уходит параметром запроса', () async {
    final feed = NearbyFeedController(mockStore(orders: repo))..start();
    addTearDown(feed.dispose);
    await settle();

    feed.setFewResponses(true);
    await settle();

    expect(feed.fewResponsesOnly, isTrue);
    expect(repo.requests.last.few, isTrue);
  });

  test('«Ближе ко мне» без геопозиции — лента новыми и пометка', () async {
    final store = mockStore(
      orders: repo,
      locator: CityLocator(
        MockCityRepository(),
        _GatedHere(null)..gate.complete(),
      ),
    );
    final feed = NearbyFeedController(store)..start();
    addTearDown(feed.dispose);

    await feed.filters.set(const NearbyFilter(sort: NearbySort.nearest));
    await settle();

    expect(feed.nearUnavailable, isTrue);
    expect(repo.requests.last.filter.near, isNull);
  });

  test('устаревший reload, ждавший геопозицию, запрос не шлёт', () async {
    final gps = _GatedHere(_moscow);
    final store = mockStore(
      orders: repo,
      locator: CityLocator(MockCityRepository(), gps),
    );
    final feed = NearbyFeedController(store)..start();
    addTearDown(feed.dispose);
    await settle();
    final before = repo.requests.length;

    // «Ближе ко мне» ждёт GPS, а пользователь уже сменил сортировку
    await feed.filters.set(const NearbyFilter(sort: NearbySort.nearest));
    await feed.filters.set(const NearbyFilter(sort: NearbySort.priceDesc));
    gps.gate.complete();
    await settle();

    expect(
      repo.requests.skip(before).map((r) => r.filter.sort),
      [NearbySort.priceDesc],
    );
    expect(feed.here, _moscow);
  });

  group('город по GPS', () {
    NearbyFilterStore gpsFilters() => NearbyFilterStore.withStorage(
      () async => null,
      (_) async {},
      CityLocator(MockCityRepository(), _GatedHere(_moscow)..gate.complete()),
    );

    test('опустошил ленту только он — onlyAutoCity', () async {
      final filters = gpsFilters();
      addTearDown(filters.dispose);
      final feed = NearbyFeedController(
        mockStore(orders: repo),
        filters: filters,
      )..start();
      addTearDown(feed.dispose);
      await filters.load();

      expect(filters.isAutoCity, isTrue);
      expect(feed.onlyAutoCity, filters.gpsCities.single);

      // ещё один фильтр — уже не только город
      feed.setFewResponses(true);
      expect(feed.onlyAutoCity, isNull);
    });

    test(
      'сброс оставляет сортировку и город по GPS, снимает остальное',
      () async {
        final filters = gpsFilters();
        addTearDown(filters.dispose);
        final feed = NearbyFeedController(
          mockStore(orders: repo),
          filters: filters,
        )..start();
        addTearDown(feed.dispose);
        await filters.load();
        await filters.set(
          filters.filter.copyWith(
            sort: NearbySort.priceDesc,
            kind: () => OrderKind.selection,
            brands: {'Kia'},
          ),
        );
        feed.setFewResponses(true);

        feed.resetFilters();
        await settle();

        expect(feed.fewResponsesOnly, isFalse);
        expect(filters.filter.sort, NearbySort.priceDesc);
        expect(filters.filter.kind, isNull);
        expect(filters.filter.brands, isEmpty);
        expect(filters.filter.cities, filters.gpsCities);
        expect(repo.requests.last.few, isFalse);
      },
    );
  });

  test('чипы включённых фильтров снимают свой фильтр', () async {
    final feed = NearbyFeedController(mockStore(orders: repo));
    addTearDown(feed.dispose);
    await feed.filters.set(
      const NearbyFilter(
        kind: OrderKind.inspection,
        minPrice: 5000,
        brands: {'Kia'},
      ),
    );

    final chips = {
      for (final (label, without) in feed.activeChips()) label: without,
    };

    expect(chips.keys, ['Осмотр', 'от 5 000 ₽', 'Kia']);
    expect(chips['Осмотр']!.kind, isNull);
    expect(chips['от 5 000 ₽']!.minPrice, isNull);
    expect(chips['Kia']!.brands, isEmpty);
  });
}
