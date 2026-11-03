import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_inspection_repository.dart';
import 'package:auto_podbor_mobile/models/inspection_panel.dart';
import 'package:auto_podbor_mobile/models/panel_condition.dart';
import 'package:auto_podbor_mobile/screens/inspection_summary_screen.dart';
import 'package:auto_podbor_mobile/screens/panel_detail_screen.dart';
import 'package:auto_podbor_mobile/state/inspection_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/app_ui.dart';

/// «Удовлетв.» требует фото, «К ремонту» — фото и дефект. Правило считает
/// сервер (поле missing), экран детали только подсказывает, а сводка не даёт
/// отправить отчёт.
void main() {
  test('missing разбирается из ответа, старый бекенд без поля — пусто', () {
    final base = {
      'id': 'hood',
      'name': 'Капот',
      'zone': 'Перед',
      'status': 'defect',
      'condition': 'needs_repair',
      'defects': <dynamic>[],
      'photo_count': 0,
    };

    final panel = InspectionPanel.fromJson({
      ...base,
      'missing': ['photo', 'defect'],
    });
    expect(panel.needsPhoto, isTrue);
    expect(panel.needsDefect, isTrue);
    expect(panel.isIncomplete, isTrue);

    expect(InspectionPanel.fromJson(base).isIncomplete, isFalse);
  });

  testWidgets('экран детали подсказывает, чего не хватает, и гасит подсказку', (
    tester,
  ) async {
    final store = InspectionStore(MockInspectionRepository());
    await store.load();
    // высокий экран: блок «Фото» должен попасть в ленивый ListView
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        // в моке крыло «К ремонту» без фото и дефектов
        home: PanelDetailScreen(store: store, panelId: 'front_right_fender'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('«К ремонту» — отметьте дефект'), findsOneWidget);
    expect(find.text('Нужно хотя бы одно фото'), findsOneWidget);

    await tester.tap(find.text('Вмятина'));
    await tester.pumpAndSettle();
    expect(find.text('«К ремонту» — отметьте дефект'), findsNothing);

    await store.uploadPhoto('front_right_fender', '/tmp/p.jpg');
    await tester.pumpAndSettle();
    expect(find.text('Нужно хотя бы одно фото'), findsNothing);
  });

  testWidgets('сводка перечисляет недоделанные пункты и не даёт отправить', (
    tester,
  ) async {
    final store = InspectionStore(MockInspectionRepository());
    await store.load();
    // оценить все пункты хорошо, кроме одного «Удовлетв.» без фото
    for (final p in store.panels) {
      if (p.condition == null) {
        await store.applyCondition(p.id, PanelCondition.good);
      }
    }
    final incomplete = store.incompletePanels.map((p) => p.id).toList();
    for (final id in incomplete.skip(1)) {
      await store.uploadPhoto(id, '/tmp/p.jpg');
      if (store.panelById(id).needsDefect) {
        await store.toggleDefect(id, 'Вмятина');
      }
    }
    final left = store.panelById(incomplete.first);
    expect(store.incompletePanels, [left]);
    expect(store.isReportComplete, isFalse);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: InspectionSummaryScreen(store: store, onSendReport: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('НЕ ХВАТАЕТ'), findsOneWidget);
    expect(find.text(left.name), findsOneWidget);
    CtaPrimary send() => tester.widget(find.byType(CtaPrimary));
    expect(send().onPressed, isNull);

    await store.uploadPhoto(left.id, '/tmp/p.jpg');
    if (store.panelById(left.id).needsDefect) {
      await store.toggleDefect(left.id, 'Вмятина');
    }
    await tester.pumpAndSettle();

    expect(find.text('НЕ ХВАТАЕТ'), findsNothing);
    expect(send().onPressed, isNotNull);
  });
}
