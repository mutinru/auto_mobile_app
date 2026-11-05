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

  test('город выбран сам — GPS не вмешивается, даже «все города»', () async {
    saved = jsonEncode({
      ...const NearbyFilter(kind: OrderKind.inspection).toJson(),
      'city_chosen': true,
    });
    final location = _Location((55.79, 49.12));
    final s = store(location);
    await s.load();
    expect(s.filter.cities, isEmpty);
    expect(s.filter.kind, OrderKind.inspection);
    expect(s.isAutoCity, isFalse);
    // город по GPS всё равно известен — к нему вернёт «Сбросить»
    expect(s.gpsCities, {'Казань'});
  });

  test('сохранены только другие фильтры — город всё равно по GPS', () async {
    saved = jsonEncode({
      ...const NearbyFilter(kind: OrderKind.inspection).toJson(),
      'city_chosen': false,
    });
    final s = store(_Location((55.79, 49.12)));
    await s.load();
    expect(s.filter.cities, {'Казань'});
    expect(s.filter.kind, OrderKind.inspection);
    expect(s.isAutoCity, isTrue);
  });

  test(
    'старая запись без city_chosen: без городов — GPS, с городом — нет',
    () async {
      saved = jsonEncode(
        const NearbyFilter(kind: OrderKind.inspection).toJson(),
      );
      final s = store(_Location((55.79, 49.12)));
      await s.load();
      expect(s.filter.cities, {'Казань'});

      saved = jsonEncode(const NearbyFilter(cities: {'Москва'}).toJson());
      final s2 = store(_Location((55.79, 49.12)));
      await s2.load();
      expect(s2.filter.cities, {'Москва'});
      expect(s2.isAutoCity, isFalse);
    },
  );

  test('«Показать» без смены города — город остаётся автоматическим', () async {
    final s = store(_Location((55.79, 49.12)));
    await s.load();
    await s.set(s.filter.copyWith(brands: const {'Kia'}));
    expect(s.filter.cities, {'Казань'});
    expect(s.filter.brands, {'Kia'});
    expect(s.isAutoCity, isTrue);
    // автогород не сохраняется — при следующем запуске GPS определит снова
    final json = jsonDecode(writes.single) as Map<String, dynamic>;
    expect(json['cities'], isEmpty);
    expect(json['city_chosen'], isFalse);
  });

  test(
    'GPS ответил, пока открыта шторка, — город не считается снятым',
    () async {
      final location = _Location((55.79, 49.12))..gate = Completer();
      final s = store(location);
      final loading = s.load();
      await pumpEventQueue();
      final opened = s.filter; // шторку открыли до ответа GPS
      location.gate!.complete();
      await loading;
      await s.set(opened.copyWith(brands: const {'Kia'}), from: opened);
      expect(s.filter.cities, {'Казань'});
      expect(s.isAutoCity, isTrue);
    },
  );

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
    expect(s.filter.cities, isEmpty);
    expect(s.isAutoCity, isFalse);
    expect(jsonDecode(writes.single)['city_chosen'], isTrue);
  });

  test('«Сбросить» после своего города — снова город по GPS', () async {
    saved = jsonEncode({
      ...const NearbyFilter(cities: {'Тула'}).toJson(),
      'city_chosen': true,
    });
    final s = store(_Location((55.79, 49.12)));
    await s.load();
    expect(s.filter.cities, {'Тула'});
    expect(s.gpsCities, {'Казань'});

    await s.set(NearbyFilter(cities: s.gpsCities));
    expect(s.filter.cities, {'Казань'});
    expect(s.isAutoCity, isTrue);
    final json = jsonDecode(writes.last) as Map<String, dynamic>;
    expect(json['city_chosen'], isFalse);
    expect(json['cities'], isEmpty);
  });

  test('«Сбросить», пока GPS не ответил, — город подставится позже', () async {
    final location = _Location((55.79, 49.12))..gate = Completer();
    final s = store(location);
    final loading = s.load();
    await pumpEventQueue();
    await s.set(const NearbyFilter());
    location.gate!.complete();
    await loading;
    await pumpEventQueue();
    expect(s.filter.cities, {'Казань'});
    expect(s.isAutoCity, isTrue);
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

  group('по пользователю (QA №30)', () {
    late Map<String, String> device;
    late int userIdCalls;

    setUp(() {
      device = {};
      userIdCalls = 0;
    });

    NearbyFilterStore forUser(int? id) => NearbyFilterStore.keyed(
      read: (key) async => device[key],
      write: (key, value) async => device[key] = value,
      delete: (key) async => device.remove(key),
      userId: () async {
        userIdCalls++;
        return id;
      },
    );

    const inspection = NearbyFilter(kind: OrderKind.inspection);

    test('у каждого аккаунта свои фильтры', () async {
      final first = forUser(1);
      await first.load();
      await first.set(inspection);

      final second = forUser(2);
      await second.load();
      expect(second.filter.kind, isNull);
      expect(device.keys, ['nearby_filter_1']);

      final again = forUser(1);
      await again.load();
      expect(again.filter.kind, OrderKind.inspection);
    });

    test('пользователь неизвестен — без хранилища', () async {
      device['nearby_filter_1'] = jsonEncode(inspection.toJson());
      final s = forUser(null);
      await s.load();
      expect(s.filter.kind, isNull);

      await s.set(inspection);
      expect(s.filter.kind, OrderKind.inspection);
      expect(device.keys, ['nearby_filter_1']);
    });

    test('старый общий фильтр не достаётся никому и удаляется', () async {
      device['nearby_filter'] = jsonEncode(inspection.toJson());
      final s = forUser(2);
      await s.load();
      expect(s.filter.kind, isNull);
      expect(device, isEmpty);
    });

    test('пользователь спрашивается один раз', () async {
      final s = forUser(1);
      await s.load();
      await s.set(inspection);
      await s.set(const NearbyFilter());
      expect(userIdCalls, 1);
    });
  });
}
