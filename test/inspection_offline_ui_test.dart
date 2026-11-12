import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:auto_podbor_mobile/data/mock_inspection_repository.dart';
import 'package:auto_podbor_mobile/models/inspection_panel.dart';
import 'package:auto_podbor_mobile/models/panel_condition.dart';
import 'package:auto_podbor_mobile/screens/inspection_summary_screen.dart';
import 'package:auto_podbor_mobile/screens/panel_detail_screen.dart';
import 'package:auto_podbor_mobile/state/inspection_outbox.dart';
import 'package:auto_podbor_mobile/state/inspection_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

/// Сервер без сети по флагу.
class _Flaky extends MockInspectionRepository {
  _Flaky() : super.blank();

  bool offline = false;

  void _net() {
    if (offline) throw http.ClientException('no network');
  }

  @override
  Future<InspectionPanel> updateCondition(
    String panelId,
    PanelCondition condition,
  ) async {
    _net();
    return super.updateCondition(panelId, condition);
  }

  @override
  Future<InspectionPanel> uploadPhoto(
    String panelId,
    String filePath, {
    String? clientId,
    PhotoSource source = PhotoSource.camera,
    String? takenAt,
  }) async {
    _net();
    return super.uploadPhoto(
      panelId,
      filePath,
      clientId: clientId,
      source: source,
      takenAt: takenAt,
    );
  }
}

/// Экраны осмотра без сети (ревью №12): действие видно сразу, плашка
/// говорит, что ещё не на сервере, отчёт ждёт синхронизации.
void main() {
  const hood = 'hood';

  setUp(() => InspectionOutbox.retryDelay = (_) => const Duration(hours: 1));

  Future<void> tallScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('деталь без сети: оценка и фото сразу, плашка «Нет связи»', (
    tester,
  ) async {
    await tallScreen(tester);
    final server = _Flaky();
    final store = InspectionStore(server);
    await store.load();
    server.offline = true;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: PanelDetailScreen(store: store, panelId: hood),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Удовлетв.'));
    await tester.pumpAndSettle();
    unawaited(store.uploadPhoto(hood, '/tmp/offline_ui.jpg'));
    await tester.pumpAndSettle();

    expect(store.panelById(hood).condition, PanelCondition.satisfactory);
    expect(find.bySemanticsLabel('не отправлено'), findsOneWidget);
    expect(find.textContaining('Нет связи — 2 изменения'), findsOneWidget);
    expect(find.text('Нужно хотя бы одно фото'), findsNothing);

    // сеть вернулась — повтор по таймеру отправил всё
    server.offline = false;
    await tester.pump(const Duration(hours: 2));
    await tester.pumpAndSettle();
    expect(store.pendingCount, 0);
    expect(find.textContaining('Нет связи'), findsNothing);
  });

  testWidgets('отчёт не отправить, пока изменения не на сервере', (
    tester,
  ) async {
    await tallScreen(tester);
    final server = _Flaky();
    // стор создаём и готовим в реальном времени: очередь, созданная в
    // часах теста, ждала бы их шагов внутри runAsync
    late final InspectionStore store;
    await tester.runAsync(() async {
      store = InspectionStore(server);
      await store.load();
      for (final p in store.panels) {
        await store.applyCondition(p.id, PanelCondition.excellent);
      }
      server.offline = true;
      await store.applyCondition(hood, PanelCondition.good);
    });
    expect(store.pendingCount, 1);

    var sent = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: InspectionSummaryScreen(
          store: store,
          onSendReport: () => sent = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Нет связи — отчёт отправится'), findsOneWidget);
    await tester.tap(find.text('Отправить отчёт клиенту'));
    expect(sent, isFalse);

    server.offline = false;
    await tester.runAsync(
      () => store.applyCondition(hood, PanelCondition.good),
    );
    await tester.pump();
    expect(store.pendingCount, 0);
    await tester.tap(find.text('Отправить отчёт клиенту'));
    expect(sent, isTrue);
  });
}
