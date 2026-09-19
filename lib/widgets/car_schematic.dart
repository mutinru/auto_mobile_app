import 'package:flutter/material.dart';

import '../models/panel_status.dart';

/// Схема кузова из макета (экран 06): SVG viewBox 0 0 360 720.
/// Пути перенесены из design/app_auto_podbor.html один в один,
/// поэтому клик по детали работает по её реальной геометрии.
class CarSchematic extends StatelessWidget {
  const CarSchematic({
    super.key,
    required this.statuses,
    required this.onTapPanel,
  });

  /// код детали -> статус (коды совпадают с body_panel_types.code)
  final Map<String, PanelStatus> statuses;
  final ValueChanged<String> onTapPanel;

  static const _w = 360.0;
  static const _h = 720.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final scale = (c.maxWidth / _w) < (c.maxHeight / _h)
            ? c.maxWidth / _w
            : c.maxHeight / _h;
        final dx = (c.maxWidth - _w * scale) / 2;
        final dy = (c.maxHeight - _h * scale) / 2;

        return GestureDetector(
          onTapUp: (details) {
            final local = details.localPosition;
            final p = Offset((local.dx - dx) / scale, (local.dy - dy) / scale);
            for (final entry in carPanelPaths.entries) {
              if (entry.value.contains(p)) {
                onTapPanel(entry.key);
                return;
              }
            }
          },
          child: CustomPaint(
            size: Size(c.maxWidth, c.maxHeight),
            painter: _CarPainter(statuses: statuses, scale: scale, dx: dx, dy: dy),
          ),
        );
      },
    );
  }
}

class _CarPainter extends CustomPainter {
  _CarPainter({
    required this.statuses,
    required this.scale,
    required this.dx,
    required this.dy,
  });

  final Map<String, PanelStatus> statuses;
  final double scale;
  final double dx;
  final double dy;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    // колёса
    final wheel = Paint()..color = const Color(0xFF0B0E11);
    final wheelStroke = Paint()
      ..color = const Color(0xFF232B34)
      ..style = PaintingStyle.stroke;
    for (final r in const [
      Rect.fromLTWH(30, 150, 30, 90),
      Rect.fromLTWH(300, 150, 30, 90),
      Rect.fromLTWH(30, 512, 30, 90),
      Rect.fromLTWH(300, 512, 30, 90),
    ]) {
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(14));
      canvas.drawRRect(rr, wheel);
      canvas.drawRRect(rr, wheelStroke);
    }

    // корпус
    canvas.drawPath(_bodyPath, Paint()..color = const Color(0xFF141A20));
    canvas.drawPath(
      _bodyPath,
      Paint()
        ..color = const Color(0xFF242D37)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // детали: заливка по статусу + обводка цветом фона, как stroke: var(--bg-0)
    final panelStroke = Paint()
      ..color = const Color(0xFF0B0D10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final entry in carPanelPaths.entries) {
      final status = statuses[entry.key] ?? PanelStatus.none;
      canvas.drawPath(entry.value, Paint()..color = status.color);
      canvas.drawPath(entry.value, panelStroke);
    }

    // фары и фонари
    final lamp = Paint()..color = const Color(0xFF2C3946);
    canvas.drawPath(_poly([84, 96, 128, 78, 134, 92, 92, 112]), lamp);
    canvas.drawPath(_poly([276, 96, 232, 78, 226, 92, 268, 112]), lamp);
    final tail = Paint()..color = const Color(0xFF3A2530);
    canvas.drawPath(_poly([92, 640, 146, 632, 148, 646, 96, 655]), tail);
    canvas.drawPath(_poly([268, 640, 214, 632, 212, 646, 264, 655]), tail);

    // стёкла
    final glass = Paint()..color = const Color(0xFF15181D);
    final glassStroke = Paint()
      ..color = const Color(0xFF0B0D10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final g in [_windshield, _rearWindow]) {
      canvas.drawPath(g, glass);
      canvas.drawPath(g, glassStroke);
    }

    // зеркала
    final mirror = Paint()..color = const Color(0xFF2C3946);
    canvas.drawPath(
      Path()
        ..moveTo(56, 258)
        ..cubicTo(40, 250, 29, 256, 32, 269)
        ..cubicTo(35, 280, 52, 278, 57, 268)
        ..close(),
      mirror,
    );
    canvas.drawPath(
      Path()
        ..moveTo(304, 258)
        ..cubicTo(320, 250, 331, 256, 328, 269)
        ..cubicTo(325, 280, 308, 278, 303, 268)
        ..close(),
      mirror,
    );

    // люк и ручки дверей
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(138, 336, 84, 58),
        const Radius.circular(10),
      ),
      Paint()..color = const Color(0xFF10161C),
    );
    final handle = Paint()..color = const Color(0x8C0F1317);
    for (final r in const [
      Rect.fromLTWH(84, 268, 12, 4),
      Rect.fromLTWH(264, 268, 12, 4),
      Rect.fromLTWH(84, 394, 12, 4),
      Rect.fromLTWH(264, 394, 12, 4),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(2)),
        handle,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CarPainter old) =>
      old.statuses != statuses || old.scale != scale;
}

Path _poly(List<double> xy) {
  final p = Path()..moveTo(xy[0], xy[1]);
  for (var i = 2; i < xy.length; i += 2) {
    p.lineTo(xy[i], xy[i + 1]);
  }
  return p..close();
}

final _bodyPath = Path()
  ..moveTo(180, 24)
  ..cubicTo(232, 24, 272, 38, 288, 84)
  ..cubicTo(298, 114, 303, 150, 305, 195)
  ..cubicTo(307, 255, 309, 320, 309, 370)
  ..cubicTo(309, 430, 307, 500, 303, 555)
  ..cubicTo(300, 606, 288, 652, 262, 674)
  ..cubicTo(240, 690, 212, 696, 180, 696)
  ..cubicTo(148, 696, 120, 690, 98, 674)
  ..cubicTo(72, 652, 60, 606, 57, 555)
  ..cubicTo(53, 500, 51, 430, 51, 370)
  ..cubicTo(51, 320, 53, 255, 55, 195)
  ..cubicTo(57, 150, 62, 114, 72, 84)
  ..cubicTo(88, 38, 128, 24, 180, 24)
  ..close();

final _windshield = Path()
  ..moveTo(106, 256)
  ..lineTo(254, 256)
  ..cubicTo(250, 279, 242, 300, 231, 314)
  ..lineTo(129, 314)
  ..cubicTo(118, 300, 110, 279, 106, 256)
  ..close();

final _rearWindow = Path()
  ..moveTo(105, 468)
  ..lineTo(255, 468)
  ..cubicTo(258, 488, 263, 504, 269, 516)
  ..lineTo(91, 516)
  ..cubicTo(97, 504, 102, 488, 105, 468)
  ..close();

/// Пути деталей. Ключи — коды из body_panel_types на бекенде.
final Map<String, Path> carPanelPaths = {
  'front_bumper': Path()
    ..moveTo(67, 150)
    ..cubicTo(69, 112, 78, 80, 92, 60)
    ..cubicTo(112, 36, 144, 30, 180, 30)
    ..cubicTo(216, 30, 248, 36, 268, 60)
    ..cubicTo(282, 80, 291, 112, 293, 150)
    ..cubicTo(258, 120, 226, 112, 180, 112)
    ..cubicTo(134, 112, 102, 120, 67, 150)
    ..close(),
  'front_left_fender': Path()
    ..moveTo(67, 154)
    ..cubicTo(62, 186, 59, 219, 58, 252)
    ..lineTo(100, 252)
    ..cubicTo(100, 218, 101, 186, 104, 158)
    ..cubicTo(90, 151, 78, 150, 67, 154)
    ..close(),
  'front_right_fender': Path()
    ..moveTo(293, 154)
    ..cubicTo(298, 186, 301, 219, 302, 252)
    ..lineTo(260, 252)
    ..cubicTo(260, 218, 259, 186, 256, 158)
    ..cubicTo(270, 151, 282, 150, 293, 154)
    ..close(),
  'hood': Path()
    ..moveTo(104, 158)
    ..cubicTo(130, 122, 150, 116, 180, 116)
    ..cubicTo(210, 116, 230, 122, 256, 158)
    ..cubicTo(259, 190, 260, 221, 260, 252)
    ..lineTo(100, 252)
    ..cubicTo(100, 221, 101, 190, 104, 158)
    ..close(),
  'front_left_door': Path()
    ..moveTo(58, 256)
    ..lineTo(100, 256)
    ..lineTo(100, 380)
    ..lineTo(57, 380)
    ..cubicTo(56.4, 338, 56.8, 297, 58, 256)
    ..close(),
  'front_right_door': Path()
    ..moveTo(302, 256)
    ..lineTo(260, 256)
    ..lineTo(260, 380)
    ..lineTo(303, 380)
    ..cubicTo(303.6, 338, 303.2, 297, 302, 256)
    ..close(),
  'rear_left_door': Path()
    ..moveTo(57, 384)
    ..lineTo(100, 384)
    ..lineTo(100, 504)
    ..lineTo(58.5, 504)
    ..cubicTo(57.4, 464, 56.9, 424, 57, 384)
    ..close(),
  'rear_right_door': Path()
    ..moveTo(303, 384)
    ..lineTo(260, 384)
    ..lineTo(260, 504)
    ..lineTo(301.5, 504)
    ..cubicTo(302.6, 464, 303.1, 424, 303, 384)
    ..close(),
  'roof': Path()
    ..moveTo(126, 318)
    ..lineTo(234, 318)
    ..cubicTo(246, 320, 252, 328, 253, 340)
    ..lineTo(255, 464)
    ..lineTo(105, 464)
    ..lineTo(107, 340)
    ..cubicTo(108, 328, 114, 320, 126, 318)
    ..close(),
  'rear_left_fender': Path()
    ..moveTo(57, 508)
    ..lineTo(100, 508)
    ..lineTo(100, 612)
    ..lineTo(64, 612)
    ..cubicTo(60.5, 578, 58.4, 544, 57, 508)
    ..close(),
  'rear_right_fender': Path()
    ..moveTo(303, 508)
    ..lineTo(260, 508)
    ..lineTo(260, 612)
    ..lineTo(296, 612)
    ..cubicTo(299.5, 578, 301.6, 544, 303, 508)
    ..close(),
  'trunk': Path()
    ..moveTo(92, 520)
    ..cubicTo(122, 529, 238, 529, 268, 520)
    ..cubicTo(265, 551, 263, 581, 261, 610)
    ..lineTo(99, 610)
    ..cubicTo(97, 581, 95, 551, 92, 520)
    ..close(),
  'rear_bumper': Path()
    ..moveTo(63, 616)
    ..lineTo(297, 616)
    ..cubicTo(294, 646, 280, 668, 254, 682)
    ..cubicTo(232, 692, 208, 696, 180, 696)
    ..cubicTo(152, 696, 128, 692, 106, 682)
    ..cubicTo(80, 668, 66, 646, 63, 616)
    ..close(),
};
