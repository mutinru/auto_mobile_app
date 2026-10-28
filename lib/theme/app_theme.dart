import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  /// Основной шрифт макета (font-family: 'Inter' в :root).
  static const fontFamily = 'Inter';

  /// Моноширинный — в макете им набраны цифры, id заказов, цены,
  /// счётчики (font-family: 'JetBrains Mono').
  static const monoFamily = 'JetBrainsMono';

  static final dark = _build(AppColors.dark, Brightness.dark);
  static final light = _build(AppColors.light, Brightness.light);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final base = ThemeData(useMaterial3: true, brightness: brightness);
    final isDark = brightness == Brightness.dark;
    return base.copyWith(
      scaffoldBackgroundColor: c.bg0,
      colorScheme: base.colorScheme.copyWith(
        surface: c.bg0,
        primary: c.statusDone,
        onPrimary: c.modeBuyInk,
        onSurface: c.text1,
        outline: c.line,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: fontFamily,
        bodyColor: c.text1,
        displayColor: c.text1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg0,
        foregroundColor: c.text1,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // иконки статус-бара — тёмные на светлой теме и наоборот
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.bg0,
        modalBarrierColor: c.backdrop,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.bg3,
        contentTextStyle: TextStyle(fontFamily: fontFamily, color: c.text1),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.statusDone),
      dividerColor: c.line,
      extensions: [c, AppText(c)],
    );
  }
}

/// Типографика прямо из CSS макета — чтобы кегли/трекинг не подбирались
/// на глаз в каждом экране. Названия соответствуют CSS-классам.
///
/// Цвет текста зависит от темы, поэтому стили строятся от [AppColors] и
/// читаются через `context.text`.
@immutable
class AppText extends ThemeExtension<AppText> {
  const AppText(this.c);

  final AppColors c;

  @override
  AppText copyWith() => this;

  @override
  AppText lerp(AppText? other, double t) =>
      other == null ? this : AppText(c.lerp(other.c, t));


  /// .detail-title — заголовок экрана
  TextStyle get detailTitle => TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.38, // -0.02em
    color: c.text1,
  );

  /// .detail-eyebrow — надстрочник над заголовком
  TextStyle get detailEyebrow => TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2, // 0.12em
    color: c.text3,
  );

  /// .section-title — подпись секции
  TextStyle get sectionTitle => TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: c.text3,
  );

  /// .section-extra — правая подпись секции (моно)
  TextStyle get sectionExtra => TextStyle(
    fontFamily: AppTheme.monoFamily,
    fontSize: 11,
    color: c.text3,
  );

  /// .order-car — название авто в карточке заказа
  TextStyle get orderCar => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15, // -0.01em
    color: c.text1,
  );

  /// .order-meta — строка параметров под названием
  TextStyle get orderMeta => TextStyle(fontSize: 12, color: c.text2);

  /// .order-id — номер заказа (моно)
  TextStyle get orderId => TextStyle(
    fontFamily: AppTheme.monoFamily,
    fontSize: 11,
    color: c.text3,
  );

  /// .order-price — цена в подвале карточки (моно)
  TextStyle get orderPrice => TextStyle(
    fontFamily: AppTheme.monoFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: c.text1,
  );

  /// .order-exec — строка про исполнителя
  TextStyle get orderExec => TextStyle(fontSize: 12, color: c.text2);

  /// .pill — статусная плашка
  TextStyle get pill => TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8, // 0.08em
  );

  /// .field-label — подпись поля формы
  TextStyle get fieldLabel => TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: c.text3,
  );

  /// .field-box — значение внутри поля
  TextStyle get fieldValue => TextStyle(fontSize: 14, color: c.text1);

  /// .field-box.empty — плейсхолдер
  TextStyle get fieldPlaceholder => TextStyle(fontSize: 14, color: c.text3);

  /// .field-mono — моноширинное значение в поле
  TextStyle get fieldMono => TextStyle(
    fontFamily: AppTheme.monoFamily,
    fontSize: 14,
    letterSpacing: 0.56, // 0.04em
    color: c.text1,
  );

  /// .chip
  TextStyle get chip => TextStyle(fontSize: 12);

  /// .cta-primary
  TextStyle get ctaPrimary => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
  );

  /// .cta-ghost
  TextStyle get ctaGhost => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: c.text2,
  );

  /// .avatar — инициалы
  TextStyle get avatar => TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: c.text1,
  );

  /// .fl-title — вопрос на стартовом экране намерения
  TextStyle get flTitle => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.72, // -0.03em
    color: c.text1,
  );

  /// .fl-sub — пояснение под вопросом
  TextStyle get flSub => TextStyle(
    fontSize: 13.5,
    color: c.text2,
    height: 1.5,
  );

  /// .fl-name — название варианта в карточке намерения
  TextStyle get flName => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
    color: c.text1,
  );

  /// .fl-desc — подпись варианта
  TextStyle get flDesc => TextStyle(
    fontSize: 11.5,
    color: c.text2,
    height: 1.4,
  );

  /// .fl-note — сноска внизу экрана намерения
  TextStyle get flNote => TextStyle(
    fontSize: 11,
    color: c.text3,
    height: 1.5,
  );
}
