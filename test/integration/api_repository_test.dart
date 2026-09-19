// Проверяет ApiInspectionRepository (тот же код, что использует
// приложение) против живого бекенда. Не входит в обычный `flutter test`
// (пришлось бы держать бекенд поднятым всегда) — запускать отдельно:
//
//   docker compose up -d
//   docker compose exec app php artisan migrate:fresh --seed
//   flutter test test/integration/api_repository_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/api_client.dart';
import 'package:auto_podbor_mobile/data/api_inspection_repository.dart';
import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/models/panel_condition.dart';
import 'package:auto_podbor_mobile/models/panel_status.dart';

void main() {
  test('login, fetch and mutate an inspection through the real API', () async {
    final auth = AuthService();
    await auth.login('inspector@autopodbor.local', 'password');
    expect(auth.isAuthenticated, isTrue);

    final repo = ApiInspectionRepository(ApiClient(auth));

    final snapshot = await repo.fetchInspection();
    expect(snapshot.car.brand, 'Toyota');
    expect(snapshot.car.model, 'Camry');
    expect(snapshot.panels, hasLength(13));
    expect(snapshot.panels.where((p) => p.status != PanelStatus.none), hasLength(9));

    final catalog = await repo.fetchDefectCatalog();
    expect(catalog, hasLength(6));

    final updated = await repo.updateCondition('rear_bumper', PanelCondition.needsRepair);
    expect(updated.status, PanelStatus.defect);
    expect(updated.condition, PanelCondition.needsRepair);

    final withDefect = await repo.toggleDefect('rear_bumper', catalog.first.id);
    expect(withDefect.defects, contains(catalog.first.label));

    final withoutDefect = await repo.toggleDefect('rear_bumper', catalog.first.id);
    expect(withoutDefect.defects, isNot(contains(catalog.first.label)));
  });
}
