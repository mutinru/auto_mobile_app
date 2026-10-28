import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// .vin-scan — имитация видоискателя камеры из макета.
///
/// Настоящего распознавания VIN нет: это заглушка под будущий
/// сканер (камера + OCR), но выглядит как в дизайне.
class VinScanner extends StatelessWidget {
  const VinScanner({super.key, required this.vin, this.onTap});

  final String vin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // видоискатель — кадр камеры, он тёмный в любой теме
    return Theme(
      data: AppTheme.dark,
      child: Builder(builder: _viewfinder),
    );
  }

  Widget _viewfinder(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 148,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            // linear-gradient(150deg, #313943, #171b21 60%, #101318)
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF313943), Color(0xFF171B21), Color(0xFF101318)],
            stops: [0, 0.6, 1],
          ),
        ),
        child: Stack(
          children: [
            // .vin-bracket — уголки рамки
            const _Bracket(top: 34, left: 34, corner: _Corner.tl),
            const _Bracket(top: 34, right: 34, corner: _Corner.tr),
            const _Bracket(bottom: 34, left: 34, corner: _Corner.bl),
            const _Bracket(bottom: 34, right: 34, corner: _Corner.br),
            // .vin-line — луч сканера
            Positioned(
              left: 34,
              right: 34,
              top: 73,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.colors.statusDone.withValues(alpha: 0),
                      context.colors.statusDone,
                      context.colors.statusDone.withValues(alpha: 0),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.statusDone.withValues(alpha: 0.6),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
            // .vin-plate
            Center(
              child: Text(
                vin,
                style: TextStyle(
                  fontFamily: AppTheme.monoFamily,
                  fontSize: 13,
                  letterSpacing: 2.08, // 0.16em
                  color: Colors.white.withValues(alpha: 0.82),
                  shadows: const [
                    Shadow(color: Color(0x99000000), blurRadius: 3, offset: Offset(0, 1)),
                  ],
                ),
              ),
            ),
            // .vin-hint
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Text(
                'наведите камеру на табличку или стекло',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.6,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Corner { tl, tr, bl, br }

class _Bracket extends StatelessWidget {
  const _Bracket({
    required this.corner,
    this.top,
    this.left,
    this.right,
    this.bottom,
  });

  final _Corner corner;
  final double? top, left, right, bottom;

  @override
  Widget build(BuildContext context) {
    final side = BorderSide(color: context.colors.statusDone, width: 2);
    const none = BorderSide.none;

    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          border: Border(
            top: corner == _Corner.tl || corner == _Corner.tr ? side : none,
            bottom: corner == _Corner.bl || corner == _Corner.br ? side : none,
            left: corner == _Corner.tl || corner == _Corner.bl ? side : none,
            right: corner == _Corner.tr || corner == _Corner.br ? side : none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(corner == _Corner.tl ? 5 : 0),
            topRight: Radius.circular(corner == _Corner.tr ? 5 : 0),
            bottomLeft: Radius.circular(corner == _Corner.bl ? 5 : 0),
            bottomRight: Radius.circular(corner == _Corner.br ? 5 : 0),
          ),
        ),
      ),
    );
  }
}
