import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Декоративная карта города из макета (.map-svg, viewBox 0 0 340 300).
/// Формы перенесены из SVG один в один — это оформление, а не реальная
/// картография: у заказов на бекенде нет координат.
class CityMapPainter extends CustomPainter {
  const CityMapPainter(this.colors);

  final MapColors colors;

  static const _w = 340.0;
  static const _h = 300.0;

  @override
  void paint(Canvas canvas, Size size) {
    // «cover»-масштаб, как preserveAspectRatio="xMidYMid slice"
    final scale = (size.width / _w) > (size.height / _h)
        ? size.width / _w
        : size.height / _h;
    canvas.save();
    canvas.translate(
      (size.width - _w * scale) / 2,
      (size.height - _h * scale) / 2,
    );
    canvas.scale(scale);

    // фон
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, _w, _h),
      Paint()..color = colors.ground,
    );

    // парковые зоны
    final park = Paint()..color = colors.park;
    canvas.drawPath(
      Path()
        ..moveTo(-10, 210)
        ..lineTo(70, 190)
        ..lineTo(110, 230)
        ..lineTo(60, 300)
        ..lineTo(-10, 300)
        ..close(),
      park,
    );
    canvas.drawPath(
      Path()
        ..moveTo(250, 20)
        ..lineTo(340, 5)
        ..lineTo(340, 70)
        ..lineTo(280, 80)
        ..close(),
      park,
    );

    // река
    canvas.drawPath(
      Path()
        ..moveTo(-10, 120)
        ..cubicTo(60, 100, 90, 160, 160, 150)
        ..cubicTo(230, 140, 260, 190, 350, 175)
        ..lineTo(350, 205)
        ..cubicTo(260, 220, 230, 172, 162, 182)
        ..cubicTo(92, 192, 62, 132, -10, 152)
        ..close(),
      Paint()..color = colors.river,
    );

    // кварталы
    final block = Paint()..color = colors.block;
    const blocks = [
      Rect.fromLTWH(18, 20, 72, 54),
      Rect.fromLTWH(104, 14, 58, 60),
      Rect.fromLTWH(176, 30, 52, 44),
      Rect.fromLTWH(20, 92, 46, 38),
      Rect.fromLTWH(132, 86, 66, 40),
      Rect.fromLTWH(216, 96, 74, 52),
      Rect.fromLTWH(26, 168, 52, 30),
      Rect.fromLTWH(128, 212, 70, 48),
      Rect.fromLTWH(212, 228, 62, 44),
      Rect.fromLTWH(288, 182, 46, 60),
    ];
    for (final r in blocks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(4)),
        block,
      );
    }

    // дороги
    final road = Paint()
      ..color = colors.road
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    canvas.drawLine(const Offset(0, 82), const Offset(340, 82), road);
    canvas.drawLine(const Offset(0, 205), const Offset(340, 205), road);
    canvas.drawLine(const Offset(98, 0), const Offset(98, 300), road);
    canvas.drawLine(const Offset(206, 0), const Offset(206, 300), road);

    final thin = Paint()
      ..color = colors.road
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawLine(const Offset(0, 145), const Offset(340, 145), thin);
    canvas.drawLine(const Offset(282, 0), const Offset(282, 300), thin);

    canvas.drawLine(
      const Offset(20, 0),
      const Offset(340, 265),
      Paint()
        ..color = colors.road
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    // МКАД
    canvas.drawCircle(
      const Offset(170, 150),
      118,
      Paint()
        ..color = colors.ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CityMapPainter oldDelegate) =>
      oldDelegate.colors != colors;
}
