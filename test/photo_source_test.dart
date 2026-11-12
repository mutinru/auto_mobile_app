import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:auto_podbor_mobile/data/photo_exif.dart';
import 'package:auto_podbor_mobile/models/inspection_panel.dart';
import 'package:auto_podbor_mobile/models/panel_status.dart';
import 'package:auto_podbor_mobile/state/inspection_op.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/photo_source_badge.dart';

/// Снимок детали из галереи (ревью №33): дата съёмки из EXIF до сжатия,
/// пометка в отчёте и подпись на весь экран.
void main() {
  List<int> jpeg({String? taken, String? offset}) {
    final image = img.Image(width: 8, height: 8);
    if (taken != null) image.exif.exifIfd[0x9003] = taken;
    if (offset != null) image.exif.exifIfd[0x9011] = offset;
    return img.encodeJpg(image);
  }

  test('дата съёмки из EXIF — в формате сервера', () {
    expect(
      takenAtFromJpeg(jpeg(taken: '2025:05:03 14:03:22')),
      '2025-05-03 14:03:22',
    );
    expect(
      takenAtFromJpeg(jpeg(taken: '2025:05:03 14:03:22', offset: '+03:00')),
      '2025-05-03 14:03:22+03:00',
    );
  });

  test('без даты и не JPEG — null', () {
    expect(takenAtFromJpeg(jpeg()), isNull);
    expect(takenAtFromJpeg(utf8.encode('не картинка')), isNull);
  });

  test('источник и дата переживают перезапуск очереди', () {
    const op = AddPhotoOp(
      id: 1,
      panelId: 'hood',
      clientId: 'k',
      path: '/q/k.jpg',
      source: PhotoSource.gallery,
      takenAt: '2025-05-03 14:03:22',
    );
    final back =
        InspectionOp.fromJson(jsonDecode(jsonEncode(op.toJson())))
            as AddPhotoOp;
    expect(back.source, PhotoSource.gallery);
    expect(back.takenAt, '2025-05-03 14:03:22');

    final old =
        InspectionOp.fromJson({
              'id': 2,
              'panel': 'hood',
              'type': 'add_photo',
              'client_id': 'k2',
              'path': '/q/k2.jpg',
            })
            as AddPhotoOp;
    expect(old.source, PhotoSource.camera, reason: 'запись до №33 — камера');

    final shown = applyPending(
      [
        InspectionPanel(
          id: 'hood',
          name: 'Капот',
          zone: 'Перед',
          status: PanelStatus.none,
        ),
      ],
      [op],
    );
    expect(shown.single.photos.single.fromGallery, isTrue);
    expect(shown.single.photos.single.takenAt, '2025-05-03 14:03:22');
  });

  test('разбор фото с сервера и подписи', () {
    final panel = InspectionPanel.fromJson({
      'id': 'hood',
      'name': 'Капот',
      'zone': 'Перед',
      'status': 'ok',
      'defects': <dynamic>[],
      'photo_count': 3,
      'photos': [
        {'id': 1, 'url': '/a', 'source': 'camera'},
        {
          'id': 2,
          'url': '/b',
          'source': 'gallery',
          'taken_at': '2025-05-03 14:03:22',
          'taken_before_start': true,
        },
        {'id': 3, 'url': '/c', 'source': 'gallery'},
      ],
    });
    final [camera, early, undated] = panel.photos;

    expect(photoSourceCaption(camera), isNull);
    expect(
      photoSourceCaption(early),
      'Из галереи · снято 03.05.2025, раньше начала осмотра',
    );
    expect(photoSourceCaption(undated), 'Из галереи · дата съёмки неизвестна');
  });

  testWidgets('пометка на плитке — только у снимка из галереи', (tester) async {
    Widget tile(PanelPhoto photo) => MaterialApp(
      theme: AppTheme.dark,
      home: SizedBox(
        width: 72,
        height: 72,
        child: Stack(children: [PhotoSourceBadge(photo: photo)]),
      ),
    );

    await tester.pumpWidget(
      tile(const PanelPhoto(id: 1, url: '/a', source: PhotoSource.camera)),
    );
    expect(find.textContaining('Галерея'), findsNothing);

    await tester.pumpWidget(
      tile(
        const PanelPhoto(
          id: 2,
          url: '/b',
          source: PhotoSource.gallery,
          takenAt: '2025-05-03 14:03:22',
        ),
      ),
    );
    expect(find.text('Галерея\n03.05.25'), findsOneWidget);

    await tester.pumpWidget(
      tile(const PanelPhoto(id: 3, url: '/c', source: PhotoSource.gallery)),
    );
    expect(find.text('Галерея\nбез даты'), findsOneWidget);
  });
}
