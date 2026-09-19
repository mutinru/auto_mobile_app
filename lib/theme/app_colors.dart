import 'package:flutter/material.dart';

/// Цвета один в один с CSS-переменными макета
/// (см. design/app_auto_podbor.html, блок :root).
class AppColors {
  AppColors._();

  static const bg0 = Color(0xFF0B0D10);
  static const bg1 = Color(0xFF15181D);
  static const bg2 = Color(0xFF1E2228);
  static const bg3 = Color(0xFF262B33);
  static const line = Color(0xFF2A2F37);

  static const text1 = Color(0xFFF2F4F7);
  static const text2 = Color(0xFF8A93A1);
  static const text3 = Color(0xFF5B6371);

  static const statusNone = Color(0xFF323843);
  static const statusProgress = Color(0xFFF5A623);
  static const statusDone = Color(0xFF5BC282);
  static const statusDefect = Color(0xFFE94B3B);
  static const statusInfo = Color(0xFF4A9BE8);

  // Акценты режимов из design/car-storefront-modes.html (:root).
  // Значения совпадают со statusDone/statusProgress, но означают режим
  // экрана, а не состояние детали — держим отдельными токенами.
  static const modeBuy = Color(0xFF5BC282);
  static const modeBuyInk = Color(0xFF07150E);
  static const modeWork = Color(0xFFF5A623);
  static const modeWorkInk = Color(0xFF1A1102);
}
