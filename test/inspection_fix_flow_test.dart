import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/mock_inspection_repository.dart';
import 'package:auto_podbor_mobile/models/panel_condition.dart';
import 'package:auto_podbor_mobile/screens/inspection_overview_screen.dart';
import 'package:auto_podbor_mobile/state/inspection_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

/// «Завершить осмотр» с недоделанными пунктами показывает шторку
/// «Осталось исправить», а не молча уводит в деталь; деталь из шторки
/// открывается в режиме исправления — «Готово» возвращает к списку,
/// а не ведёт по всем деталям подряд.
void main() {
  /// Осмотр из мока, где оценено всё, кроме последнего пункта («Документы»);
  /// недозаполненные пункты мока (бампер без фото и др.) остаются.
  Future<InspectionStore> almostDone() async {
    final store = InspectionStore(MockInspectionRepository());
    await store.load();
    for (final p in store.panels) {
      if (p.condition == null && p.id != 'documents') {
        await store.applyCondition(p.id, PanelCondition.good);
      }
    }
    return store;
  }

  /// Дозаполнить всё, чего не хватает (фото и дефект), через стор.
  Future<void> fixAll(InspectionStore store) async {
    for (final p in store.incompletePanels) {
      if (p.needsPhoto) await store.uploadPhoto(p.id, '/tmp/p.jpg');
      if (store.panelById(p.id).needsDefect) {
        await store.toggleDefect(p.id, 'Вмятина');
      }
    }
  }

  Future<void> pumpOverview(WidgetTester tester, InspectionStore store) async {
    // высокий экран: шторка со всем списком и блок «Фото» помещаются
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: InspectionOverviewScreen(store: store, onSendReport: () {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Режим исправления мигает блоком по таймеру — дождаться его.
  Future<void> settleFix(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  Future<void> finishFromLastPanel(WidgetTester tester) async {
    expect(find.text('ПРОДОЛЖИТЬ'), findsOneWidget);
    await tester.tap(find.text('ПРОДОЛЖИТЬ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Хорошее'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Завершить осмотр'));
    await tester.pumpAndSettle();
  }

  testWidgets('«Завершить» с недоделками — шторка с причинами, а не деталь', (
    tester,
  ) async {
    final store = await almostDone();
    await pumpOverview(tester, store);
    await finishFromLastPanel(tester);

    final left = store.problems;
    expect(left, isNotEmpty);
    expect(find.text('Осталось исправить · ${left.length}'), findsOneWidget);
    expect(find.text('Передний бампер'), findsOneWidget);
    expect(find.text('нужно фото'), findsWidgets);
    // остались на схеме под шторкой, а не в карточке детали
    expect(find.text('СОСТОЯНИЕ'), findsNothing);
  });

  testWidgets('деталь из шторки: плашка, «Готово» — назад к списку', (
    tester,
  ) async {
    final store = await almostDone();
    await pumpOverview(tester, store);
    await finishFromLastPanel(tester);
    final before = store.problems.length;

    await tester.tap(find.text('Передний бампер'));
    await settleFix(tester);

    expect(find.text('Чтобы отправить отчёт: добавьте фото'), findsOneWidget);
    expect(find.text('Готово'), findsOneWidget);
    expect(find.text('ОСТАЛОСЬ ИСПРАВИТЬ · $before'), findsOneWidget);
    // в режиме исправления «Дальше» по порядку нет
    expect(find.text('ДАЛЬШЕ'), findsNothing);

    await store.uploadPhoto('front_bumper', '/tmp/p.jpg');
    await tester.pumpAndSettle();
    expect(find.textContaining('Чтобы отправить отчёт'), findsNothing);
    expect(find.text('ОСТАЛОСЬ ИСПРАВИТЬ · ${before - 1}'), findsOneWidget);

    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();

    // снова шторка, бампера в ней нет
    expect(find.text('Осталось исправить · ${before - 1}'), findsOneWidget);
    expect(find.text('Передний бампер'), findsNothing);
  });

  testWidgets('исправил всё в шторке — «Сформировать отчёт» ведёт в сводку', (
    tester,
  ) async {
    final store = await almostDone();
    await pumpOverview(tester, store);
    await finishFromLastPanel(tester);

    await fixAll(store);
    await tester.pumpAndSettle();
    expect(find.text('Всё заполнено'), findsOneWidget);

    // кнопка шторки; под ней у схемы — такая же
    await tester.tap(find.text('Сформировать отчёт').last);
    await tester.pumpAndSettle();
    expect(find.text('Сводка'), findsOneWidget);
  });

  testWidgets('всё заполнено — «Завершить осмотр» сразу открывает сводку', (
    tester,
  ) async {
    final store = await almostDone();
    await fixAll(store);
    await pumpOverview(tester, store);
    await finishFromLastPanel(tester);

    expect(find.text('Сводка'), findsOneWidget);
    expect(find.textContaining('Осталось исправить'), findsNothing);
  });

  testWidgets(
    'схема после прохода: «Осталось исправить · N» открывает шторку',
    (
      tester,
    ) async {
      final store = await almostDone();
      await store.applyCondition('documents', PanelCondition.good);
      await pumpOverview(tester, store);

      final n = store.problems.length;
      expect(find.text('ОСТАЛОСЬ ИСПРАВИТЬ · $n'), findsOneWidget);
      expect(find.text('ДОЗАПОЛНИТЬ'), findsNothing);

      await tester.tap(find.text('Показать, что не так'));
      await tester.pumpAndSettle();
      expect(find.text('Осталось исправить · $n'), findsOneWidget);
    },
  );
}
