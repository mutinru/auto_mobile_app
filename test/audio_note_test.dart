import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_inspection_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/screens/inspection_report_screen.dart';
import 'package:auto_podbor_mobile/screens/panel_detail_screen.dart';
import 'package:auto_podbor_mobile/state/inspection_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

/// Голосовая заметка к детали. Запись и воспроизведение — плагины, в
/// виджет-тестах их нет: «Записать» и ▶ здесь не нажимаем, заметку кладём
/// через стор, как её вернул бы сервер.
void main() {
  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
  }

  Future<InspectionStore> loadedStore({bool readOnly = false}) async {
    final store = InspectionStore(MockInspectionRepository(), readOnly: readOnly);
    await store.load();
    return store;
  }

  Widget panelApp(InspectionStore store) => MaterialApp(
        theme: AppTheme.dark,
        home: PanelDetailScreen(store: store, panelId: 'hood'),
      );

  testWidgets('без заметки — «нет записи» и кнопка «Записать»', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(panelApp(await loadedStore()));

    expect(find.text('нет записи'), findsOneWidget);
    expect(find.text('Записать'), findsOneWidget);
    expect(find.text('Удалить'), findsNothing);
  });

  testWidgets('заметка с сервера: плеер, перезапись и удаление', (tester) async {
    tallScreen(tester);
    final store = await loadedStore();
    await store.uploadAudioNote('hood', '/tmp/note.m4a', 18);
    await tester.pumpWidget(panelApp(store));

    expect(find.text('0:18'), findsOneWidget);
    expect(find.byTooltip('Слушать'), findsOneWidget);
    expect(find.text('Перезаписать'), findsOneWidget);

    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    expect(find.text('Удалить заметку?'), findsOneWidget);

    // основная кнопка листа подтверждения
    await tester.tap(find.text('Удалить').last);
    await tester.pumpAndSettle();

    expect(store.panelById('hood').audioNoteSeconds, isNull);
    expect(find.text('нет записи'), findsOneWidget);
    expect(find.text('Записать'), findsOneWidget);
  });

  testWidgets('только просмотр — слушать можно, править нельзя', (tester) async {
    tallScreen(tester);
    final store = await loadedStore(readOnly: true);
    await store.uploadAudioNote('hood', '/tmp/note.m4a', 7);
    await tester.pumpWidget(panelApp(store));

    expect(find.byTooltip('Слушать'), findsOneWidget);
    expect(find.text('Записать'), findsNothing);
    expect(find.text('Перезаписать'), findsNothing);
    expect(find.text('Удалить'), findsNothing);
  });

  testWidgets('отчёт: секция заметки только у детали с записью', (tester) async {
    tallScreen(tester);
    final store = await loadedStore(readOnly: true);
    await store.uploadAudioNote('hood', '/tmp/note.m4a', 18);
    final order = await MockOrderRepository().fetchOrder(2047);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: InspectionReportScreen(store: store, order: order),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Капот').first);
    await tester.pumpAndSettle();
    expect(find.text('ГОЛОСОВАЯ ЗАМЕТКА'), findsOneWidget);
    expect(find.byTooltip('Слушать'), findsOneWidget);
    expect(find.text('Записать'), findsNothing);

    Navigator.of(tester.element(find.text('ГОЛОСОВАЯ ЗАМЕТКА'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Крыша').first);
    await tester.pumpAndSettle();
    // лист крыши открылся, а заметки у неё нет
    expect(find.text('Фото нет'), findsOneWidget);
    expect(find.text('ГОЛОСОВАЯ ЗАМЕТКА'), findsNothing);
  });
}
