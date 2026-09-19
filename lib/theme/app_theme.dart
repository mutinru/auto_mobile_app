import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  /// Основной шрифт макета (font-family: 'Inter' в :root).
  static const fontFamily = 'Inter';

  /// Моноширинный — в макете им набраны цифры, id заказов, цены,
  /// счётчики (font-family: 'JetBrains Mono').
  static const monoFamily = 'JetBrainsMono';

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg0,
      colorScheme: base.colorScheme.copyWith(
        surface: AppColors.bg0,
        primary: AppColors.statusDone,
        onSurface: AppColors.text1,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: fontFamily,
        bodyColor: AppColors.text1,
        displayColor: AppColors.text1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg0,
        foregroundColor: AppColors.text1,
        elevation: 0,
        centerTitle: false,
      ),
      dividerColor: AppColors.line,
    );
  }
}

/// Типографика прямо из CSS макета — чтобы кегли/трекинг не подбирались
/// на глаз в каждом экране. Названия соответствуют CSS-классам.
class AppText {
  AppText._();

  /// .detail-title — заголовок экрана
  static const detailTitle = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.38, // -0.02em
    color: AppColors.text1,
  );

  /// .detail-eyebrow — надстрочник над заголовком
  static const detailEyebrow = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2, // 0.12em
    color: AppColors.text3,
  );

  /// .section-title — подпись секции
  static const sectionTitle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: AppColors.text3,
  );

  /// .section-extra — правая подпись секции (моно)
  static const sectionExtra = TextStyle(
    fontFamily: AppTheme.monoFamily,
    fontSize: 11,
    color: AppColors.text3,
  );

  /// .order-car — название авто в карточке заказа
  static const orderCar = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15, // -0.01em
    color: AppColors.text1,
  );

  /// .order-meta — строка параметров под названием
  static const orderMeta = TextStyle(fontSize: 12, color: AppColors.text2);

  /// .order-id — номер заказа (моно)
  static const orderId = TextStyle(
    fontFamily: AppTheme.monoFamily,
    fontSize: 11,
    color: AppColors.text3,
  );

  /// .order-price — цена в подвале карточки (моно)
  static const orderPrice = TextStyle(
    fontFamily: AppTheme.monoFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.text1,
  );

  /// .order-exec — строка про исполнителя
  static const orderExec = TextStyle(fontSize: 12, color: AppColors.text2);

  /// .pill — статусная плашка
  static const pill = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8, // 0.08em
  );

  /// .field-label — подпись поля формы
  static const fieldLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: AppColors.text3,
  );

  /// .field-box — значение внутри поля
  static const fieldValue = TextStyle(fontSize: 14, color: AppColors.text1);

  /// .field-box.empty — плейсхолдер
  static const fieldPlaceholder = TextStyle(fontSize: 14, color: AppColors.text3);

  /// .field-mono — моноширинное значение в поле
  static const fieldMono = TextStyle(
    fontFamily: AppTheme.monoFamily,
    fontSize: 14,
    letterSpacing: 0.56, // 0.04em
    color: AppColors.text1,
  );

  /// .chip
  static const chip = TextStyle(fontSize: 12);

  /// .cta-primary
  static const ctaPrimary = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
  );

  /// .cta-ghost
  static const ctaGhost = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.text2,
  );

  /// .avatar — инициалы
  static const avatar = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: AppColors.text1,
  );

  /// .fl-title — вопрос на стартовом экране намерения
  static const flTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.72, // -0.03em
    color: AppColors.text1,
  );

  /// .fl-sub — пояснение под вопросом
  static const flSub = TextStyle(
    fontSize: 13.5,
    color: AppColors.text2,
    height: 1.5,
  );

  /// .fl-name — название варианта в карточке намерения
  static const flName = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
    color: AppColors.text1,
  );

  /// .fl-desc — подпись варианта
  static const flDesc = TextStyle(
    fontSize: 11.5,
    color: AppColors.text2,
    height: 1.4,
  );

  /// .fl-note — сноска внизу экрана намерения
  static const flNote = TextStyle(
    fontSize: 11,
    color: AppColors.text3,
    height: 1.5,
  );
}
