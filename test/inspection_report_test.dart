import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/mock_inspection_repository.dart';
import 'package:auto_podbor_mobile/data/mock_order_repository.dart';
import 'package:auto_podbor_mobile/screens/inspection_order_detail_screen.dart';
import 'package:auto_podbor_mobile/screens/inspection_report_screen.dart';
import 'package:auto_podbor_mobile/state/inspection_store.dart';
import 'package:auto_podbor_mobile/state/order_store.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/order_card.dart';

/// Полный отчёт осмотра глазами заказчика — только чтение.
void main() {
  /// Отчёт длинный — высокий экран, чтобы ленивый ListView построил всё.
  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
  }

  Future<Widget> reportApp() async {
    final store = InspectionStore(MockInspectionRepository());
    await store.load();
    // дефект на крыле, чтобы проверить «Найденные дефекты» и лист детали
    await store.toggleDefect('front_right_fender', 'Вмятина');
    final order = await MockOrderRepository().fetchOrder(2047);
    return MaterialApp(
      theme: AppTheme.dark,
      home: InspectionReportScreen(store: store, order: order),
    );
  }

  testWidgets('отчёт: вердикт, балл, дефекты и детали без кнопок правки', (
    tester,
  ) async {
    tallScreen(tester);
    await tester.pumpWidget(await reportApp());
    await tester.pumpAndSettle();

    expect(find.text('Не рекомендую'), findsOneWidget);
    expect(find.text('НАЙДЕННЫЕ ДЕФЕКТЫ'), findsOneWidget);
    expect(find.text('Вмятина'), findsOneWidget);
    expect(find.text('Капот'), findsOneWidget);
    // в моке одна деталь с дефектом — крыло на «D»
    expect(find.text('деталь с дефектами'), findsOneWidget);
    // группы по оценке, а не по ходу работы
    expect(find.text('К РЕМОНТУ'), findsOneWidget);
    expect(find.text('ЕСТЬ ЗАМЕЧАНИЯ'), findsOneWidget);
    expect(find.text('В ПОРЯДКЕ'), findsOneWidget);
    expect(find.text('НЕ ОЦЕНЕНО'), findsOneWidget);
    expect(find.text('ГОТОВО'), findsNothing);
    expect(find.text('Отправить отчёт клиенту'), findsNothing);
    expect(find.text('Скачать PDF'), findsNothing);
  });

  testWidgets('тап по детали открывает лист с оценкой и дефектами', (
    tester,
  ) async {
    tallScreen(tester);
    await tester.pumpWidget(await reportApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Переднее правое крыло').first);
    await tester.pumpAndSettle();

    expect(find.text('D · К ремонту'), findsOneWidget);
    expect(find.text('Фото нет'), findsOneWidget);
    // в листе нет ни выбора состояния, ни добавления фото
    expect(find.text('Отличное'), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('деталь заказа: «Полный отчёт» только при наличии auth', (
    tester,
  ) async {
    Widget detail(AuthService? auth) => MaterialApp(
      theme: AppTheme.dark,
      home: InspectionOrderDetailScreen(
        store: OrderStore(MockOrderRepository()),
        orderId: 2047,
        auth: auth,
      ),
    );

    await tester.pumpWidget(detail(AuthService()));
    await tester.pumpAndSettle();
    expect(find.text('Полный отчёт'), findsOneWidget);

    await tester.pumpWidget(detail(null));
    await tester.pumpAndSettle();
    expect(find.text('Полный отчёт'), findsNothing);
  });

  testWidgets('карточка: «Посмотреть полный отчёт» вместо ссылки «Отчёт»', (
    tester,
  ) async {
    final order = await MockOrderRepository().fetchOrder(2047);
    var opened = false;
    Widget card(VoidCallback? onReport) => MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: OrderCard(order: order, onTap: () {}, onReport: onReport),
      ),
    );

    await tester.pumpWidget(card(() => opened = true));
    expect(find.text('Отчёт'), findsNothing);
    await tester.tap(find.text('Посмотреть полный отчёт'));
    expect(opened, isTrue);

    await tester.pumpWidget(card(null));
    expect(find.text('Посмотреть полный отчёт'), findsNothing);
  });
}
