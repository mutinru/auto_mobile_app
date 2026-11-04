import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/config/api_config.dart';
import 'package:auto_podbor_mobile/data/mock_inspection_repository.dart';
import 'package:auto_podbor_mobile/models/inspection_panel.dart';
import 'package:auto_podbor_mobile/screens/panel_detail_screen.dart';
import 'package:auto_podbor_mobile/state/inspection_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/photo_viewer.dart';

/// Фото детали (QA №26): по тапу — на весь экран с листанием, исполнитель
/// там же удаляет ошибочный снимок, заказчик только смотрит.
void main() {
  // в моке крыло «К ремонту» без фото и дефектов
  const fender = 'front_right_fender';

  Future<InspectionStore> storeWithPhotos(
    int count, {
    bool readOnly = false,
  }) async {
    final store = InspectionStore(
      MockInspectionRepository(),
      readOnly: readOnly,
    );
    await store.load();
    for (var i = 0; i < count; i++) {
      await store.uploadPhoto(fender, '/tmp/p$i.jpg');
    }
    return store;
  }

  Future<void> openDetail(WidgetTester tester, InspectionStore store) async {
    // высокий экран: блок «Фото» должен попасть в ленивый ListView
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: PanelDetailScreen(store: store, panelId: fender),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Миниатюры на экране детали — по порядку загрузки.
  Finder thumb(int i) => find
      .descendant(
        of: find.byType(PanelDetailScreen),
        matching: find.byType(Image),
      )
      .at(i);

  test('фото разбираются с id и абсолютной ссылкой', () {
    final panel = InspectionPanel.fromJson({
      'id': 'hood',
      'name': 'Капот',
      'zone': 'Перед',
      'status': 'ok',
      'condition': 'good',
      'defects': <dynamic>[],
      'photo_count': 1,
      'photos': [
        {'id': 42, 'url': '/api/media/photos/42?signature=x', 'label': null},
      ],
    });

    expect(panel.photos.single.id, 42);
    expect(
      panel.photos.single.url,
      '${ApiConfig.origin}/api/media/photos/42?signature=x',
    );
  });

  testWidgets('тап по миниатюре открывает фото с листанием', (tester) async {
    final store = await storeWithPhotos(2);
    await openDetail(tester, store);

    await tester.tap(thumb(1));
    await tester.pumpAndSettle();

    expect(find.byType(PhotoViewer), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(600, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('исполнитель удаляет фото — деталь снова требует снимок', (
    tester,
  ) async {
    final store = await storeWithPhotos(1);
    await openDetail(tester, store);
    expect(find.text('1/5'), findsOneWidget);
    expect(find.text('Нужно хотя бы одно фото'), findsNothing);

    await tester.tap(thumb(0));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Удалить фото'));
    await tester.pumpAndSettle();

    // подтверждение — без него ничего не удаляется
    expect(find.text('Удалить фото?'), findsOneWidget);
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    expect(find.byType(PhotoViewer), findsNothing);
    expect(store.panelById(fender).photos, isEmpty);
    expect(find.text('0/5'), findsOneWidget);
    expect(find.text('Нужно хотя бы одно фото'), findsOneWidget);
  });

  testWidgets('отмена удаления оставляет фото', (tester) async {
    final store = await storeWithPhotos(1);
    await openDetail(tester, store);

    await tester.tap(thumb(0));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Удалить фото'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(find.byType(PhotoViewer), findsOneWidget);
    expect(store.panelById(fender).photos, hasLength(1));
  });

  testWidgets('заказчик смотрит фото без кнопки удаления', (tester) async {
    final store = await storeWithPhotos(1, readOnly: true);
    await openDetail(tester, store);

    await tester.tap(thumb(0));
    await tester.pumpAndSettle();

    expect(find.byType(PhotoViewer), findsOneWidget);
    expect(find.byTooltip('Удалить фото'), findsNothing);
    // одно фото — без счётчика «1 / 1»
    expect(find.text('1 / 1'), findsNothing);
  });
}
