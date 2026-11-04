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
    // непрозрачная зелёная подложка: выбранное поле часов, выделенный пункт.
    // buySoft полупрозрачный — на слоях диалога он бы мутнел по-разному
    final greenSoft = Color.alphaBlend(
      c.statusDone.withValues(alpha: isDark ? 0.22 : 0.16),
      c.bg1,
    );
    return base.copyWith(
      scaffoldBackgroundColor: c.bg0,
      // Схема заполнена целиком: встроенные виджеты Material (выбор даты и
      // времени, диалоги, меню вставки) берут контейнерные тона отсюда, и
      // незаданные Material выводил из своего фиолетового сида.
      colorScheme: base.colorScheme.copyWith(
        surface: c.bg0,
        onSurface: c.text1,
        onSurfaceVariant: c.text2,
        surfaceTint: Colors.transparent,
        surfaceContainerLowest: c.bg0,
        surfaceContainerLow: c.bg1,
        surfaceContainer: c.bg1,
        surfaceContainerHigh: c.bg1,
        surfaceContainerHighest: c.bg2,
        primary: c.statusDone,
        onPrimary: c.modeBuyInk,
        primaryContainer: greenSoft,
        onPrimaryContainer: c.doneText,
        secondary: c.statusDone,
        onSecondary: c.modeBuyInk,
        secondaryContainer: greenSoft,
        onSecondaryContainer: c.doneText,
        tertiary: c.statusDone,
        onTertiary: c.modeBuyInk,
        tertiaryContainer: greenSoft,
        onTertiaryContainer: c.doneText,
        error: c.statusDefect,
        onError: c.modeBuyInk,
        outline: c.line,
        outlineVariant: c.line,
        inverseSurface: c.text1,
        onInverseSurface: c.bg0,
        inversePrimary: c.statusDone,
      ),
      textTheme: _lightWeight(
        base.textTheme.apply(
          fontFamily: fontFamily,
          bodyColor: c.text1,
          displayColor: c.text1,
        ),
        isDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg0,
        foregroundColor: c.text1,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // иконки статус-бара — тёмные на светлой теме и наоборот
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
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
      dialogTheme: DialogThemeData(backgroundColor: c.bg1),
      timePickerTheme: _timePicker(c, greenSoft),
      datePickerTheme: _datePicker(c),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.statusDone,
        selectionColor: c.statusDone.withValues(alpha: 0.35),
        selectionHandleColor: c.statusDone,
      ),
      dividerColor: c.line,
      extensions: [c, AppText(c)],
    );
  }

  /// Кнопки «Отмена»/«ОК» встроенных диалогов — текстом акцента.
  static ButtonStyle _dialogButton(AppColors c) => TextButton.styleFrom(
    foregroundColor: c.doneText,
    textStyle: const TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w600,
    ),
  );

  /// Выбор времени («Точное время» в заявке на осмотр).
  static TimePickerThemeData _timePicker(AppColors c, Color greenSoft) {
    // выбранное поле часов/минут — зелёная подложка, остальное — bg2
    Color field(Set<WidgetState> s) =>
        s.contains(WidgetState.selected) ? greenSoft : c.bg2;
    Color fieldText(Set<WidgetState> s) =>
        s.contains(WidgetState.selected) ? c.doneText : c.text1;
    return TimePickerThemeData(
      backgroundColor: c.bg1,
      helpTextStyle: TextStyle(fontFamily: fontFamily, color: c.text2),
      hourMinuteColor: WidgetStateColor.resolveWith(field),
      hourMinuteTextColor: WidgetStateColor.resolveWith(fieldText),
      hourMinuteTextStyle: const TextStyle(
        fontFamily: fontFamily,
        fontSize: 48,
        fontWeight: FontWeight.w500,
      ),
      timeSelectorSeparatorColor: WidgetStatePropertyAll(c.text1),
      dialBackgroundColor: c.bg2,
      dialHandColor: c.statusDone,
      dialTextColor: WidgetStateColor.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.modeBuyInk : c.text1,
      ),
      dialTextStyle: const TextStyle(fontFamily: fontFamily, fontSize: 16),
      entryModeIconColor: c.text2,
      cancelButtonStyle: _dialogButton(c),
      confirmButtonStyle: _dialogButton(c),
    );
  }

  /// Выбор даты («Другая дата» в заявке на осмотр).
  static DatePickerThemeData _datePicker(AppColors c) {
    final selected = WidgetState.selected;
    final disabled = WidgetState.disabled;
    return DatePickerThemeData(
      backgroundColor: c.bg1,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: c.bg1,
      headerForegroundColor: c.text1,
      headerHelpStyle: TextStyle(fontFamily: fontFamily, color: c.text2),
      weekdayStyle: TextStyle(fontFamily: fontFamily, color: c.text2),
      dividerColor: c.line,
      dayForegroundColor: WidgetStateColor.resolveWith(
        (s) => s.contains(selected)
            ? c.modeBuyInk
            : s.contains(disabled)
            ? c.text3
            : c.text1,
      ),
      dayBackgroundColor: WidgetStateColor.resolveWith(
        (s) => s.contains(selected) ? c.statusDone : Colors.transparent,
      ),
      todayForegroundColor: WidgetStateColor.resolveWith(
        (s) => s.contains(selected)
            ? c.modeBuyInk
            : s.contains(disabled)
            ? c.text3
            : c.doneText,
      ),
      todayBackgroundColor: WidgetStateColor.resolveWith(
        (s) => s.contains(selected) ? c.statusDone : Colors.transparent,
      ),
      todayBorder: BorderSide(color: c.statusDone),
      yearForegroundColor: WidgetStateColor.resolveWith(
        (s) => s.contains(selected)
            ? c.modeBuyInk
            : s.contains(disabled)
            ? c.text3
            : c.text1,
      ),
      yearBackgroundColor: WidgetStateColor.resolveWith(
        (s) => s.contains(selected) ? c.statusDone : Colors.transparent,
      ),
      cancelButtonStyle: _dialogButton(c),
      confirmButtonStyle: _dialogButton(c),
    );
  }

  /// В светлой теме обычный текст — w500: Inter w400 на солнце выглядит
  /// волосяным. Через DefaultTextStyle это доходит и до inline-TextStyle без
  /// явного веса; явные w600/w700 не трогаются.
  static TextTheme _lightWeight(TextTheme t, bool isDark) {
    if (isDark) return t;
    TextStyle? m(TextStyle? s) => s?.copyWith(fontWeight: FontWeight.w500);
    return t.copyWith(
      bodyLarge: m(t.bodyLarge),
      bodyMedium: m(t.bodyMedium),
      bodySmall: m(t.bodySmall),
      labelLarge: m(t.labelLarge),
      labelMedium: m(t.labelMedium),
      labelSmall: m(t.labelSmall),
      titleMedium: m(t.titleMedium),
      titleSmall: m(t.titleSmall),
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

  /// Вес обычного текста: в светлой теме плотнее (см. AppTheme._lightWeight).
  FontWeight? get _regular => c.isLight ? FontWeight.w500 : null;

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
    fontWeight: _regular,
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
  TextStyle get orderMeta =>
      TextStyle(fontSize: 12, fontWeight: _regular, color: c.text2);

  /// .order-id — номер заказа (моно)
  TextStyle get orderId => TextStyle(
    fontFamily: AppTheme.monoFamily,
    fontSize: 11,
    fontWeight: _regular,
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
  TextStyle get orderExec =>
      TextStyle(fontSize: 12, fontWeight: _regular, color: c.text2);

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
  TextStyle get fieldValue =>
      TextStyle(fontSize: 14, fontWeight: _regular, color: c.text1);

  /// .field-box.empty — плейсхолдер
  TextStyle get fieldPlaceholder =>
      TextStyle(fontSize: 14, fontWeight: _regular, color: c.textHint);

  /// .field-mono — моноширинное значение в поле
  TextStyle get fieldMono => TextStyle(
    fontFamily: AppTheme.monoFamily,
    fontSize: 14,
    fontWeight: _regular,
    letterSpacing: 0.56, // 0.04em
    color: c.text1,
  );

  /// .chip
  TextStyle get chip => TextStyle(fontSize: 12, fontWeight: _regular);

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
    fontWeight: _regular,
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
    fontWeight: _regular,
    color: c.text2,
    height: 1.4,
  );

  /// .fl-note — сноска внизу экрана намерения
  TextStyle get flNote => TextStyle(
    fontSize: 11,
    fontWeight: _regular,
    color: c.text3,
    height: 1.5,
  );
}
