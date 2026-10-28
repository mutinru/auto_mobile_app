import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// .score-ring — кольцо прогресса из макета (r=34, ширина 6, скруглённый конец).
class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.percent, this.color});

  /// 0..100
  final int percent;
  /// null — зелёный statusDone текущей темы.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      height: 78,
      child: CustomPaint(
        painter: _RingPainter(
          percent: percent,
          color: color ?? context.colors.statusDone,
          track: context.colors.bg3,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.percent,
    required this.color,
    required this.track,
  });

  final int percent;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const r = 34.0;
    final center = Offset(size.width / 2, size.height / 2);

    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2,
      2 * math.pi * (percent.clamp(0, 100) / 100),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.percent != percent || old.color != color || old.track != track;
}
