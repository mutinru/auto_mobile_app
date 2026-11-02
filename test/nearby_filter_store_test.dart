import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/city_repository.dart';
import 'package:auto_podbor_mobile/data/location_service.dart';
import 'package:auto_podbor_mobile/models/city.dart';
import 'package:auto_podbor_mobile/models/nearby_filter.dart';
import 'package:auto_podbor_mobile/models/order_kind.dart';
import 'package:auto_podbor_mobile/state/city_locator.dart';
import 'package:auto_podbor_mobile/state/nearby_filter_store.dart';

/// GPS без плагина: [point] — что «вернул GPS», [gate] — придержать ответ.
class _Location implements LocationService {
  _Location(this.point, {this.granted = true});

  final (double, double)? point;
  final bool granted;
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<bool> isGranted() async => granted;

  @override
  Future<(double, double)?> current() async {
    calls++;
    await gate?.future;
    return point;
  }
}

/// Ближайший город — всегда Казань.
class _Cities implements CityRepository {
  @override
  Future<City?> nearest(double lat, double lon) async => const City(
    id: 'kazan',
    name: 'Казань',
    region: 'Респ Татарстан',
    lat: 55.79,
    lon: 49.12,
  );

  @override
  Future<List<City>> search(String query) async => const [];
}

void main() {
  String? saved;
  final writes = <String>[];

  setUp(() {
    saved = null;
    writes.clear();
  });

  NearbyFilterStore store(_Location location) => NearbyFilterStore.withStorage(
    () async => saved,
    (value) async => writes.add(value),
    CityLocator(_Cities(), location),
  );

  test('фильтр не задан — город по GPS, в хранилище не пишется', () async {
    final s = store(_Location((55.79, 49.12)));
    await s.load();
    expect(s.filter.cities, {'Казань'});
    expect(s.isAutoCity, isTrue);
    expect(writes, isEmpty);
  });

  test('сохранённый фильтр — GPS не вмешивается, даже без городов', () async {
    saved = jsonEncode(const NearbyFilter(kind: OrderKind.inspection).toJson());
    final location = _Location((55.79, 49.12));
    final s = store(location);
    await s.load();
    expect(s.filter.cities, isEmpty);
    expect(s.filter.kind, OrderKind.inspection);
    expect(s.isAutoCity, isFalse);
    expect(location.calls, 0);
  });

  test('выбор во время ожидания GPS автогород не перетирает', () async {
    final location = _Location((55.79, 49.12))..gate = Completer();
    final s = store(location);
    final loading = s.load();
    await pumpEventQueue();
    await s.set(const NearbyFilter(cities: {'Москва'}));
    location.gate!.complete();
    await loading;
    expect(s.filter.cities, {'Москва'});
    expect(s.isAutoCity, isFalse);
    expect(writes, hasLength(1));
  });

  test('правка после автогорода сохраняется и снимает признак', () async {
    final s = store(_Location((55.79, 49.12)));
    await s.load();
    await s.set(s.filter.copyWith(cities: const {}));
    expect(s.isAutoCity, isFalse);
    expect(writes, hasLength(1));
  });

  test('GPS не дал точку — фильтр пустой', () async {
    final s = store(_Location(null));
    await s.load();
    expect(s.filter.isEmpty, isTrue);
    expect(s.isAutoCity, isFalse);
  });

  group('CityLocator.warmUp', () {
    test('без разрешения GPS не трогает', () async {
      final location = _Location((55.79, 49.12), granted: false);
      await CityLocator(_Cities(), location).warmUp();
      expect(location.calls, 0);
    });

    test(
      'с разрешением — город готов, detect() не спрашивает GPS снова',
      () async {
        final location = _Location((55.79, 49.12));
        final locator = CityLocator(_Cities(), location);
        await locator.warmUp();
        expect(location.calls, 1);
        expect((await locator.detect())?.name, 'Казань');
        expect(location.calls, 1);
      },
    );
  });
}
