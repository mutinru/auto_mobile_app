import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Палитра приложения. Две версии — [AppColors.dark] и [AppColors.light] —
/// перенесены из CSS-переменных макета design/first-launch-screen.html
/// (блоки `:root[data-theme="dark"]` и `:root[data-theme="light"]`).
///
/// Лежит в теме как [ThemeExtension], поэтому читается через
/// `context.colors` — экран зависит от темы и перекрашивается при её смене.
/// Захардкоженных `Color(0x…)` в экранах быть не должно: всё, что меняется
/// между темами, — токен здесь.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg0,
    required this.bg1,
    required this.bg2,
    required this.bg3,
    required this.line,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.statusNone,
    required this.statusProgress,
    required this.statusDone,
    required this.statusDefect,
    required this.statusInfo,
    required this.modeBuy,
    required this.modeBuyInk,
    required this.buySoft,
    required this.buyEdge,
    required this.modeWork,
    required this.modeWorkInk,
    required this.workSoft,
    required this.workEdge,
    required this.infoInk,
    required this.infoSoft,
    required this.online,
    required this.backdrop,
    required this.sheetShadow,
    required this.cardShadow,
    required this.knob,
    required this.knobInk,
    required this.avatarFrom,
    required this.avatarTo,
    required this.schematic,
    required this.map,
  });

  final Color bg0;
  final Color bg1;
  final Color bg2;
  final Color bg3;
  final Color line;

  final Color text1;
  final Color text2;
  final Color text3;

  final Color statusNone;
  final Color statusProgress;
  final Color statusDone;
  final Color statusDefect;
  final Color statusInfo;

  // Акценты режимов из design/car-storefront-modes.html (:root).
  // Значения совпадают со statusDone/statusProgress, но означают режим
  // экрана, а не состояние детали — держим отдельными токенами.
  final Color modeBuy;

  /// Текст и иконки поверх [modeBuy] (и [statusDone]).
  final Color modeBuyInk;

  /// --buy-soft / --buy-edge — заливка и рамка карточки «Ищу автомобиль».
  final Color buySoft;
  final Color buyEdge;

  final Color modeWork;

  /// Текст поверх [modeWork] (и [statusProgress]) — тёмный в обеих темах.
  final Color modeWorkInk;
  final Color workSoft;
  final Color workEdge;

  /// Текст и иконки поверх [statusInfo].
  final Color infoInk;

  /// --info-soft — подложка выделенного пункта.
  final Color infoSoft;

  /// --online — точка «поддержка на связи».
  final Color online;

  /// Затемнение под шторкой.
  final Color backdrop;

  /// Тень шторки, поднятой снизу.
  final Color sheetShadow;

  /// Лёгкая тень карточек — только в светлой теме, в тёмной прозрачна.
  final Color cardShadow;

  /// Бегунок переключателя темы и иконка на нём.
  final Color knob;
  final Color knobInk;

  /// Градиент аватара-заглушки с инициалами.
  final Color avatarFrom;
  final Color avatarTo;

  final SchematicColors schematic;
  final MapColors map;

  bool get isLight => bg0.computeLuminance() > 0.5;

  static const dark = AppColors(
    bg0: Color(0xFF0B0D10),
    bg1: Color(0xFF15181D),
    bg2: Color(0xFF1E2228),
    bg3: Color(0xFF262B33),
    line: Color(0xFF2A2F37),
    text1: Color(0xFFF2F4F7),
    text2: Color(0xFF8A93A1),
    text3: Color(0xFF5B6371),
    statusNone: Color(0xFF323843),
    statusProgress: Color(0xFFF5A623),
    statusDone: Color(0xFF5BC282),
    statusDefect: Color(0xFFE94B3B),
    statusInfo: Color(0xFF4A9BE8),
    modeBuy: Color(0xFF5BC282),
    modeBuyInk: Color(0xFF07150E),
    buySoft: Color(0x0F5BC282),
    buyEdge: Color(0x735BC282),
    modeWork: Color(0xFFF5A623),
    modeWorkInk: Color(0xFF1A1102),
    workSoft: Color(0x0FF5A623),
    workEdge: Color(0x73F5A623),
    infoInk: Color(0xFF04121F),
    infoSoft: Color(0x244A9BE8),
    online: Color(0xFF5BC282),
    backdrop: Color(0x8C000000),
    sheetShadow: Color(0x8C000000),
    cardShadow: Color(0x00000000),
    knob: Color(0xFFF2F4F7),
    knobInk: Color(0xFF0B0D10),
    avatarFrom: Color(0xFF5A6470),
    avatarTo: Color(0xFF2C3138),
    schematic: SchematicColors.dark,
    map: MapColors.dark,
  );

  static const light = AppColors(
    // фон экрана — светло-серый, не белый; карточки белые поверх него
    bg0: Color(0xFFF5F6F8),
    bg1: Color(0xFFFFFFFF),
    bg2: Color(0xFFF0F2F5),
    bg3: Color(0xFFE6E9EE),
    line: Color(0xFFDFE3E9),
    text1: Color(0xFF12151A),
    text2: Color(0xFF5A6372),
    text3: Color(0xFF8C94A1),
    statusNone: Color(0xFFCDD2DA),
    statusProgress: Color(0xFFF2A11F),
    // зелёный и синий темнее — для контраста на светлом
    statusDone: Color(0xFF2E9E5E),
    statusDefect: Color(0xFFD63B2C),
    statusInfo: Color(0xFF2F7FD1),
    modeBuy: Color(0xFF2E9E5E),
    modeBuyInk: Color(0xFFFFFFFF),
    buySoft: Color(0x122E9E5E),
    buyEdge: Color(0x662E9E5E),
    // оранжевый остаётся ярким, текст на нём тёмный
    modeWork: Color(0xFFF2A11F),
    modeWorkInk: Color(0xFF1A1102),
    workSoft: Color(0x17F2A11F),
    workEdge: Color(0x73E28C0A),
    infoInk: Color(0xFFFFFFFF),
    infoSoft: Color(0x1A2F7FD1),
    online: Color(0xFF2E9E5E),
    backdrop: Color(0x5212151A),
    sheetShadow: Color(0x2412151A),
    cardShadow: Color(0x0A12151A),
    knob: Color(0xFF12151A),
    knobInk: Color(0xFFFFFFFF),
    avatarFrom: Color(0xFFD5DAE1),
    avatarTo: Color(0xFFA9B1BD),
    schematic: SchematicColors.light,
    map: MapColors.light,
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bg0: l(bg0, other.bg0),
      bg1: l(bg1, other.bg1),
      bg2: l(bg2, other.bg2),
      bg3: l(bg3, other.bg3),
      line: l(line, other.line),
      text1: l(text1, other.text1),
      text2: l(text2, other.text2),
      text3: l(text3, other.text3),
      statusNone: l(statusNone, other.statusNone),
      statusProgress: l(statusProgress, other.statusProgress),
      statusDone: l(statusDone, other.statusDone),
      statusDefect: l(statusDefect, other.statusDefect),
      statusInfo: l(statusInfo, other.statusInfo),
      modeBuy: l(modeBuy, other.modeBuy),
      modeBuyInk: l(modeBuyInk, other.modeBuyInk),
      buySoft: l(buySoft, other.buySoft),
      buyEdge: l(buyEdge, other.buyEdge),
      modeWork: l(modeWork, other.modeWork),
      modeWorkInk: l(modeWorkInk, other.modeWorkInk),
      workSoft: l(workSoft, other.workSoft),
      workEdge: l(workEdge, other.workEdge),
      infoInk: l(infoInk, other.infoInk),
      infoSoft: l(infoSoft, other.infoSoft),
      online: l(online, other.online),
      backdrop: l(backdrop, other.backdrop),
      sheetShadow: l(sheetShadow, other.sheetShadow),
      cardShadow: l(cardShadow, other.cardShadow),
      knob: l(knob, other.knob),
      knobInk: l(knobInk, other.knobInk),
      avatarFrom: l(avatarFrom, other.avatarFrom),
      avatarTo: l(avatarTo, other.avatarTo),
      // рисунки не плавные — переключаются на середине перехода
      schematic: t < 0.5 ? schematic : other.schematic,
      map: t < 0.5 ? map : other.map,
    );
  }
}

/// Цвета схемы кузова (lib/widgets/car_schematic.dart). Тёмные значения —
/// из design/app_auto_podbor.html, светлые подобраны под светлую палитру.
@immutable
class SchematicColors {
  const SchematicColors({
    required this.wheel,
    required this.wheelStroke,
    required this.body,
    required this.bodyStroke,
    required this.panelStroke,
    required this.lamp,
    required this.tail,
    required this.glass,
    required this.sunroof,
    required this.handle,
  });

  final Color wheel;
  final Color wheelStroke;
  final Color body;
  final Color bodyStroke;

  /// Обводка деталей и стёкол — цвет фона экрана (stroke: var(--bg-0)).
  final Color panelStroke;
  final Color lamp;
  final Color tail;
  final Color glass;
  final Color sunroof;
  final Color handle;

  static const dark = SchematicColors(
    wheel: Color(0xFF0B0E11),
    wheelStroke: Color(0xFF232B34),
    body: Color(0xFF141A20),
    bodyStroke: Color(0xFF242D37),
    panelStroke: Color(0xFF0B0D10),
    lamp: Color(0xFF2C3946),
    tail: Color(0xFF3A2530),
    glass: Color(0xFF15181D),
    sunroof: Color(0xFF10161C),
    handle: Color(0x8C0F1317),
  );

  static const light = SchematicColors(
    wheel: Color(0xFF2A2F37),
    wheelStroke: Color(0xFF4A525E),
    body: Color(0xFFE1E5EA),
    bodyStroke: Color(0xFFC3CAD3),
    panelStroke: Color(0xFFF5F6F8),
    lamp: Color(0xFFB7C4D2),
    tail: Color(0xFFE3B5BE),
    glass: Color(0xFFC2CBD5),
    sunroof: Color(0xFFCBD2DA),
    handle: Color(0x5912151A),
  );
}

/// Цвета декоративной карты (lib/widgets/city_map.dart).
@immutable
class MapColors {
  const MapColors({
    required this.ground,
    required this.park,
    required this.river,
    required this.block,
    required this.road,
    required this.ring,
  });

  final Color ground;
  final Color park;
  final Color river;
  final Color block;
  final Color road;

  /// Кольцевая (МКАД).
  final Color ring;

  static const dark = MapColors(
    ground: Color(0xFF0F1216),
    park: Color(0xFF131B18),
    river: Color(0xFF12202B),
    block: Color(0xFF161A20),
    road: Color(0xFF1D232B),
    ring: Color(0xFF232A33),
  );

  static const light = MapColors(
    ground: Color(0xFFECEFF3),
    park: Color(0xFFDCEBDF),
    river: Color(0xFFCDE0F1),
    block: Color(0xFFE0E4EA),
    road: Color(0xFFFFFFFF),
    ring: Color(0xFFD0D6DE),
  );
}

/// Доступ к палитре и типографике текущей темы. Если тема собрана не
/// через [AppTheme] (голый MaterialApp в виджет-тесте), берём тёмную —
/// исторически приложение было только тёмным.
extension AppThemeContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.dark;
  AppText get text => Theme.of(this).extension<AppText>() ?? AppText(colors);
}
