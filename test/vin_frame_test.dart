import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/widgets/vin_frame.dart';

/// Пересчёт рамки с экрана камеры в кадр снимка (превью по BoxFit.cover).
void main() {
  // кадр 3:4 портретом
  const preview = Size(300, 400);

  test('экран той же формы — доли совпадают с экраном', () {
    final p = pointInImage(
      preview: preview,
      viewport: const Size(600, 800),
      point: const Offset(150, 200),
    );
    expect(p.dx, closeTo(0.25, 1e-9));
    expect(p.dy, closeTo(0.25, 1e-9));
  });

  test('экран вытянутее кадра — превью обрезано по бокам', () {
    // 400x800: превью растянуто до 600x800, по 100 px срезано слева и справа
    const viewport = Size(400, 800);
    final left = pointInImage(
      preview: preview,
      viewport: viewport,
      point: Offset.zero,
    );
    expect(left.dx, closeTo(100 / 600, 1e-9));
    expect(left.dy, 0);
    final center = pointInImage(
      preview: preview,
      viewport: viewport,
      point: const Offset(200, 400),
    );
    expect(center.dx, closeTo(0.5, 1e-9));
    expect(center.dy, closeTo(0.5, 1e-9));
  });

  test('экран шире кадра — превью обрезано сверху и снизу', () {
    // 600x600: превью 600x800, по 100 px срезано сверху и снизу
    final top = pointInImage(
      preview: preview,
      viewport: const Size(600, 600),
      point: Offset.zero,
    );
    expect(top.dx, 0);
    expect(top.dy, closeTo(100 / 800, 1e-9));
  });

  test('рамка получает запас: по высоте больше, чем по ширине', () {
    final frame = frameInImage(
      preview: preview,
      viewport: const Size(600, 800),
      // рамка 0.2..0.8 по ширине, 0.4..0.5 по высоте
      frameOnScreen: const Rect.fromLTRB(120, 320, 480, 400),
    );
    expect(frame.left, closeTo(0.2 - 0.6 * 0.05, 1e-9));
    expect(frame.right, closeTo(0.8 + 0.6 * 0.05, 1e-9));
    // по высоте — не больше пары строк таблички (QA 2026-11-05 №4)
    expect(frame.top, closeTo(0.4 - 0.1 * 0.15, 1e-9));
    expect(frame.bottom, closeTo(0.5 + 0.1 * 0.15, 1e-9));
  });

  test('запас не выходит за края кадра', () {
    final frame = frameInImage(
      preview: preview,
      viewport: const Size(600, 800),
      frameOnScreen: const Rect.fromLTRB(0, 0, 600, 100),
    );
    expect(frame.left, 0);
    expect(frame.top, 0);
    expect(frame.right, 1);
  });

  group('превью → снимок другой формы (QA 2026-11-05 №4)', () {
    // портрет: превью 9:16 (поток 1920x1080), снимок 3:4 (сенсор 4000x3000)
    const preview916 = Size(1080, 1920);
    const photo34 = Size(3000, 4000);

    test('снимок шире превью — доли сжимаются к середине по ширине', () {
      final p = previewPointToImage(
        const Offset(0, 0.25),
        preview: preview916,
        image: photo34,
      );
      // превью занимает 0.5625 / 0.75 = 0.75 ширины снимка, по центру
      expect(p.dx, closeTo(0.125, 1e-9));
      expect(p.dy, closeTo(0.25, 1e-9));
    });

    test('рамка во всю ширину превью — середина снимка, высота та же', () {
      final r = previewToImage(
        const Rect.fromLTRB(0.06, 0.38, 0.94, 0.46),
        preview: preview916,
        image: photo34,
      );
      expect(r.left, closeTo(0.5 - 0.44 * 0.75, 1e-9));
      expect(r.right, closeTo(0.5 + 0.44 * 0.75, 1e-9));
      expect(r.top, closeTo(0.38, 1e-9));
      expect(r.bottom, closeTo(0.46, 1e-9));
    });

    test('снимок выше превью — сжимается высота', () {
      final p = previewPointToImage(
        const Offset(0.25, 0),
        preview: photo34,
        image: preview916,
      );
      expect(p.dx, closeTo(0.25, 1e-9));
      expect(p.dy, closeTo(0.5 - 0.5 * 0.75, 1e-9));
    });

    test('одной формы — доли не меняются, размер не важен', () {
      final p = previewPointToImage(
        const Offset(0.3, 0.7),
        preview: const Size(300, 400),
        image: photo34,
      );
      expect(p.dx, closeTo(0.3, 1e-9));
      expect(p.dy, closeTo(0.7, 1e-9));
    });
  });
}
