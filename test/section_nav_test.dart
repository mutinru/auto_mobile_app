import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/navigation/section_nav.dart';

/// Стек разделов: вопрос → дом → профиль → другой раздел, без копий
/// (QA 2026-11-05 №2).
void main() {
  late GlobalKey<NavigatorState> navigator;
  late SectionNav nav;
  late List<String> stack;

  /// Заглушки экранов: имя на экране, кнопки — переходы, как в приложении.
  Widget screen(String name) => Scaffold(body: Text(name));

  Widget home(HomeSection s) => screen(_name(s));

  Future<void> start(WidgetTester tester) async {
    navigator = GlobalKey<NavigatorState>();
    stack = [];
    nav = SectionNav(() => navigator.currentState!);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [_StackObserver(stack)],
        home: screen('вопрос'),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) => tester.pumpAndSettle();

  Future<void> back(WidgetTester tester) async {
    await navigator.currentState!.maybePop();
    await settle(tester);
  }

  /// Иконка профиля, раздел из профиля — как их зовёт _RootGate.
  Future<void> profile(WidgetTester tester) async {
    nav.openProfile(() => screen('профиль'));
    await settle(tester);
  }

  Future<void> fromProfile(WidgetTester tester, HomeSection s) async {
    nav.openFromProfile(s, () => home(s));
    await settle(tester);
  }

  testWidgets('цепочка «профиль ↔ разделы» не плодит копий', (tester) async {
    await start(tester);
    nav.openHome(HomeSection.nearby, () => home(HomeSection.nearby));
    await settle(tester);
    expect(stack, ['вопрос', 'рядом']);

    final steps = <(String, Future<void> Function(), List<String>)>[
      ('профиль', () => profile(tester), ['вопрос', 'рядом', 'профиль']),
      (
        'мои из профиля',
        () => fromProfile(tester, HomeSection.myOrders),
        ['вопрос', 'рядом', 'профиль', 'мои'],
      ),
      (
        'профиль из моих',
        () => profile(tester),
        ['вопрос', 'рядом', 'профиль'],
      ),
      (
        'дом из профиля',
        () => fromProfile(tester, HomeSection.nearby),
        ['вопрос', 'рядом'],
      ),
      ('профиль', () => profile(tester), ['вопрос', 'рядом', 'профиль']),
      (
        'мои из профиля',
        () => fromProfile(tester, HomeSection.myOrders),
        ['вопрос', 'рядом', 'профиль', 'мои'],
      ),
      (
        'профиль из моих',
        () => profile(tester),
        ['вопрос', 'рядом', 'профиль'],
      ),
    ];
    for (final (label, step, expected) in steps) {
      await step();
      expect(stack, expected, reason: label);
      expect(find.text(expected.last), findsOneWidget, reason: label);
    }

    await back(tester);
    expect(stack, ['вопрос', 'рядом']);
    await back(tester);
    expect(stack, ['вопрос']);
    expect(nav.home, isNull);
  });

  testWidgets('профиль → другой раздел → «назад» → профиль → дом', (
    tester,
  ) async {
    await start(tester);
    nav.openHome(HomeSection.nearby, () => home(HomeSection.nearby));
    await settle(tester);
    await profile(tester);
    await fromProfile(tester, HomeSection.myOrders);

    await back(tester);
    expect(find.text('профиль'), findsOneWidget);
    await back(tester);
    expect(find.text('рядом'), findsOneWidget);
    expect(nav.home, HomeSection.nearby);
  });

  testWidgets('профиль, закрытый «назад», открывается заново', (
    tester,
  ) async {
    await start(tester);
    nav.openHome(HomeSection.myOrders, () => home(HomeSection.myOrders));
    await settle(tester);
    await profile(tester);
    await back(tester);
    expect(nav.profileOpen, isFalse);

    var built = 0;
    nav.openProfile(() {
      built++;
      return screen('профиль');
    });
    await settle(tester);
    expect(built, 1);
    expect(stack, ['вопрос', 'мои', 'профиль']);
  });

  testWidgets('возврат к открытому экрану не строит новый', (tester) async {
    await start(tester);
    nav.openHome(HomeSection.myOrders, () => home(HomeSection.myOrders));
    await settle(tester);
    await profile(tester);

    var built = 0;
    nav.openFromProfile(HomeSection.myOrders, () {
      built++;
      return home(HomeSection.myOrders);
    });
    await settle(tester);
    expect(built, 0, reason: 'это дом — к нему возвращаемся');
    expect(stack, ['вопрос', 'мои']);
  });

  testWidgets('новый дом и сброс оставляют только вопрос внизу', (
    tester,
  ) async {
    await start(tester);
    nav.openHome(HomeSection.myOrders, () => home(HomeSection.myOrders));
    await settle(tester);
    await profile(tester);
    await fromProfile(tester, HomeSection.nearby);

    nav.openHome(HomeSection.nearby, () => home(HomeSection.nearby));
    await settle(tester);
    expect(stack, ['вопрос', 'рядом']);
    expect(nav.home, HomeSection.nearby);
    expect(nav.profileOpen, isFalse);

    nav.reset();
    await settle(tester);
    expect(stack, ['вопрос']);
    expect(nav.home, isNull);
  });

  testWidgets('дом без анимации появляется сразу', (tester) async {
    await start(tester);
    nav.openHome(
      HomeSection.nearby,
      () => home(HomeSection.nearby),
      animate: false,
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('рядом'), findsOneWidget);
    expect(find.text('вопрос'), findsNothing);
  });
}

String _name(HomeSection s) => switch (s) {
  HomeSection.myOrders => 'мои',
  HomeSection.nearby => 'рядом',
};

/// Стек маршрутов по именам экранов: имя берём из текста на экране —
/// у корня настроек нет.
class _StackObserver extends NavigatorObserver {
  _StackObserver(this.stack);

  final List<String> stack;

  String _label(Route<dynamic> route) => switch (route.settings.name) {
    '/' || null => 'вопрос',
    'profile' => 'профиль',
    final name => _name(
      HomeSection.values.byName(name.substring(name.indexOf(':') + 1)),
    ),
  };

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      stack.add(_label(route));

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      stack.removeLast();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      stack.remove(_label(route));
}
