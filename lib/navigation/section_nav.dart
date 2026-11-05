import 'package:flutter/material.dart';

/// Раздел, который можно выбрать на вопросе о намерении, — «дом».
enum HomeSection { myOrders, nearby }

/// Правила стека разделов (QA 2026-11-05 №2). В корне всегда вопрос о
/// намерении, над ним — «дом», выбранный на нём раздел. Профиль и разделы
/// из профиля кладутся поверх:
///
///     вопрос → дом → профиль → другой раздел
///
/// Копий не бывает: профиль, уже лежащий в стеке, не кладётся второй раз —
/// к нему возвращаются; раздел из профиля, совпадающий с домом, — тоже
/// возврат к дому. Поэтому стек не глубже четырёх экранов, сколько ни ходи
/// «профиль ↔ разделы», а «назад» всегда ведёт вниз по этой цепочке.
///
/// Разделы открывать только через этот класс: `push` раздела руками вернёт
/// копии.
///
/// Экран передаётся фабрикой [ScreenFactory]: она зовётся один раз и только
/// если экран действительно кладётся. Не в `builder` маршрута — тот
/// вызывается заново при смене темы, и экран получил бы новые сторы.
typedef ScreenFactory = Widget Function();

class SectionNav {
  SectionNav(this._navigator);

  final NavigatorState Function() _navigator;

  Route<void>? _home;
  HomeSection? _homeSection;
  Route<void>? _profile;

  /// Открытый дом. null — дома в стеке нет (виден вопрос о намерении).
  HomeSection? get home => (_home?.isActive ?? false) ? _homeSection : null;

  /// Профиль сейчас в стеке.
  bool get profileOpen => _profile?.isActive ?? false;

  /// Дом поверх вопроса; всё, что было над вопросом, снимается.
  /// [animate] = false — без анимации появления (запуск сразу в последний
  /// раздел: вопрос не должен мелькать), «назад» анимируется как обычно.
  void openHome(
    HomeSection section,
    ScreenFactory screen, {
    bool animate = true,
  }) {
    final navigator = _navigator();
    navigator.popUntil((route) => route.isFirst);
    final child = screen();
    final settings = RouteSettings(name: 'home:${section.name}');
    final route = animate
        ? MaterialPageRoute<void>(builder: (_) => child, settings: settings)
        : _AppearInstantly<void>(builder: (_) => child, settings: settings);
    _home = route;
    _homeSection = section;
    _profile = null;
    navigator.push(route);
  }

  /// Иконка профиля: уже открытый — вернуться к нему, иначе положить.
  void openProfile(ScreenFactory screen) {
    final navigator = _navigator();
    final open = _profile;
    if (open != null && open.isActive) {
      navigator.popUntil((route) => route == open);
      return;
    }
    final child = screen();
    final route = MaterialPageRoute<void>(
      builder: (_) => child,
      settings: const RouteSettings(name: 'profile'),
    );
    _profile = route;
    navigator.push(route);
  }

  /// Раздел из профиля: дом — вернуться к нему, иначе положить поверх
  /// профиля («назад» вернёт в профиль).
  void openFromProfile(HomeSection section, ScreenFactory screen) {
    final navigator = _navigator();
    final home = _home;
    if (section == this.home && home != null) {
      navigator.popUntil((route) => route == home);
      return;
    }
    final child = screen();
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => child,
        settings: RouteSettings(name: 'section:${section.name}'),
      ),
    );
  }

  /// Выход или истёкшая сессия: остаётся только вопрос о намерении.
  void reset() {
    _navigator().popUntil((route) => route.isFirst);
    _home = null;
    _homeSection = null;
    _profile = null;
  }
}

/// Появляется без анимации, уходит — с обычной.
class _AppearInstantly<T> extends MaterialPageRoute<T> {
  _AppearInstantly({required super.builder, super.settings});

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);
}
