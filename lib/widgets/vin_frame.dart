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

/// Рамка экрана в долях **превью** с запасом: рука дрогнула при съёмке, а
/// строка VIN на снимке не должна обрезаться. По высоте запас больше —
/// рамка узкая, и сдвиг вверх-вниз выводит строку из неё первым. Но не
/// больше пары строк: на мелком снимке ±35 % захватывали соседние надписи
/// таблички (QA 2026-11-05 №4) — от дрожания теперь страхует выбор строки,
/// ближайшей к центру рамки ([textNearest]). В доли снимка рамку переводит
/// [previewToImage] — по настоящему размеру снимка.
Rect frameInImage({
  required Size preview,
  required Size viewport,
  required Rect frameOnScreen,
  double padX = 0.05,
  double padY = 0.15,
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

/// Точка в долях превью → в доли снимка. Поток превью и снимок идут с одного
/// сенсора, но часто разной формы: превью 16:9, снимок — полный сенсор 4:3.
/// Превью — центральная обрезка снимка: более узкий кадр лежит внутри по
/// центру, поэтому доли сжимаются к середине по той стороне, где снимок
/// шире. [preview] и [image] — портретные размеры (после поворота по EXIF).
Offset previewPointToImage(
  Offset point, {
  required Size preview,
  required Size image,
}) {
  final previewAspect = preview.width / preview.height;
  final imageAspect = image.width / image.height;
  // снимок шире превью — превью занимает его середину по ширине
  final kx = imageAspect > previewAspect ? previewAspect / imageAspect : 1.0;
  // снимок выше превью — середину по высоте
  final ky = imageAspect < previewAspect ? imageAspect / previewAspect : 1.0;
  return Offset(0.5 + (point.dx - 0.5) * kx, 0.5 + (point.dy - 0.5) * ky);
}

/// Рамка в долях превью → в доли снимка ([previewPointToImage]).
Rect previewToImage(
  Rect frame, {
  required Size preview,
  required Size image,
}) => Rect.fromPoints(
  previewPointToImage(frame.topLeft, preview: preview, image: image),
  previewPointToImage(frame.bottomRight, preview: preview, image: image),
);

/// Строка распознанного текста и её место на картинке (в пикселях той
/// картинки, что распознавали).
typedef OcrLine = ({String text, Rect box});

/// Текст строками от ближайшей к [centerY] (центр рамки, в пикселях той же
/// картинки) к дальней. Разборщики номера (`extractVin`, `guessVin`,
/// `extractBodyNumber`) берут первое совпадение по порядку текста — значит,
/// победит строка, на которую наводили рамку, а не верхняя на табличке.
String textNearest(List<OcrLine> lines, double centerY) {
  // List.sort не устойчива: при равном расстоянии держим порядок ML Kit
  final order = [for (var i = 0; i < lines.length; i++) i]
    ..sort((a, b) {
      final da = (lines[a].box.center.dy - centerY).abs();
      final db = (lines[b].box.center.dy - centerY).abs();
      return da != db ? da.compareTo(db) : a.compareTo(b);
    });
  return order.map((i) => lines[i].text).join('\n');
}
