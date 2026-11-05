import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/navigation/section_nav.dart';
import 'package:auto_podbor_mobile/state/last_section.dart';

/// Последний дом переживает перезапуск и стирается при выходе
/// (QA 2026-11-05 №19).
void main() {
  LastSection over(Map<String, String> disk, {bool broken = false}) =>
      LastSection.withStorage(
        read: (key) async =>
            broken ? throw Exception('нет хранилища') : disk[key],
        write: (key, value) async =>
            broken ? throw Exception('нет хранилища') : disk[key] = value,
        delete: (key) async =>
            broken ? throw Exception('нет хранилища') : disk.remove(key),
      );

  test('сохранённое читается после перезапуска', () async {
    final disk = <String, String>{};
    await over(disk).save(HomeSection.nearby);

    final restarted = over(disk);
    await restarted.load();
    expect(restarted.value, HomeSection.nearby);
  });

  test('выход стирает', () async {
    final disk = <String, String>{};
    final last = over(disk);
    await last.save(HomeSection.myOrders);
    await last.clear();
    expect(last.value, isNull);

    final restarted = over(disk);
    await restarted.load();
    expect(restarted.value, isNull);
  });

  test('мусор в хранилище — как не выбирали', () async {
    final last = over({'last_section': 'profile'});
    await last.load();
    expect(last.value, isNull);
  });

  test('сломанное хранилище не роняет и помнит до перезапуска', () async {
    final last = over({}, broken: true);
    await last.load();
    expect(last.value, isNull);
    await last.save(HomeSection.nearby);
    expect(last.value, HomeSection.nearby);
    await last.clear();
    expect(last.value, isNull);
  });
}
