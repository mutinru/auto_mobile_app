import 'dart:math' as math;
import 'dart:ui';

/// Пересчёт с экрана камеры в кадр снимка. Превью растянуто на весь экран
/// по `BoxFit.cover`: лишнее у превью обрезано по краям, поэтому точка
/// экрана и точка кадра не совпадают. Результат — доли кадра (0..1) в
/// портретной ориентации, как снимок после поворота по EXIF.
///
/// [preview] — размер превью в портретной ориентации (короткая сторона —
/// ширина), [viewport] — область экрана, на которой оно растянуто.
Offset pointInImage({
  required Size preview,
  required Size viewport,
  required Offset point,
}) {
  final scale = math.max(
    viewport.width / preview.width,
    viewport.height / preview.height,
  );
  final shown = Size(preview.width * scale, preview.height * scale);
  // превью по центру: при обрезке смещение отрицательное
  final dx = (viewport.width - shown.width) / 2;
  final dy = (viewport.height - shown.height) / 2;
  return Offset(
    ((point.dx - dx) / shown.width).clamp(0.0, 1.0),
    ((point.dy - dy) / shown.height).clamp(0.0, 1.0),
  );
}

/// Рамка экрана в долях кадра с запасом: рука дрогнула при съёмке, а
/// строка VIN на снимке не должна обрезаться. По высоте запас больше —
/// рамка узкая, и сдвиг вверх-вниз выводит строку из неё первым.
Rect frameInImage({
  required Size preview,
  required Size viewport,
  required Rect frameOnScreen,
  double padX = 0.05,
  double padY = 0.35,
}) {
  final tl = pointInImage(
    preview: preview,
    viewport: viewport,
    point: frameOnScreen.topLeft,
  );
  final br = pointInImage(
    preview: preview,
    viewport: viewport,
    point: frameOnScreen.bottomRight,
  );
  final w = br.dx - tl.dx;
  final h = br.dy - tl.dy;
  return Rect.fromLTRB(
    (tl.dx - w * padX).clamp(0.0, 1.0),
    (tl.dy - h * padY).clamp(0.0, 1.0),
    (br.dx + w * padX).clamp(0.0, 1.0),
    (br.dy + h * padY).clamp(0.0, 1.0),
  );
}
