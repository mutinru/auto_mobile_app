import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_inspection_repository.dart';
import 'package:auto_podbor_mobile/models/inspection_panel.dart';
import 'package:auto_podbor_mobile/screens/panel_detail_screen.dart';
import 'package:auto_podbor_mobile/state/inspection_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

/// Сервер отвечает, когда тест разрешит: виден «запрос в пути».
class _SlowDefects extends MockInspectionRepository {
  final calls = <bool>[];
  Completer<void>? gate;

  @override
  Future<InspectionPanel> setDefect(
    String panelId,
    int defectId, {
    required bool on,
  }) async {
    calls.add(on);
    await gate?.future;
    return super.setDefect(panelId, defectId, on: on);
  }
}

/// Дефект — явным состоянием (ревью №6): повтор «поставить» не снимает
/// дефект, а второй тап по чипу, пока идёт первый запрос, не уходит (№38).
void main() {
  test('повтор «поставить» дефект не снимает', () async {
    final repo = MockInspectionRepository();
    final store = InspectionStore(repo);
    await store.load();
    final dent = (await repo.fetchDefectCatalog()).firstWhere(
      (d) => d.label == 'Вмятина',
    );

    await repo.setDefect('front_right_fender', dent.id, on: true);
    final again = await repo.setDefect('front_right_fender', dent.id, on: true);
    expect(again.defects.where((d) => d == 'Вмятина'), hasLength(1));

    final off = await repo.setDefect('front_right_fender', dent.id, on: false);
    expect(off.defects, isNot(contains('Вмятина')));
  });

  testWidgets('двойной тап по дефекту — один запрос «поставить»', (
    tester,
  ) async {
    final repo = _SlowDefects();
    final store = InspectionStore(repo);
    await store.load();
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: PanelDetailScreen(store: store, panelId: 'front_right_fender'),
      ),
    );
    await tester.pumpAndSettle();

    repo.gate = Completer<void>();
    await tester.tap(find.text('Вмятина'));
    await tester.pump();
    await tester.tap(find.text('Вмятина'));
    await tester.pump();
    repo.gate!.complete();
    await tester.pumpAndSettle();

    expect(repo.calls, [true]);
    expect(store.panelById('front_right_fender').defects, contains('Вмятина'));
  });
}
