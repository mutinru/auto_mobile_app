import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Короткая сторона снимка на сервер: 4:3 — 1920×1440. Деталь и приборка
/// читаются без потерь, а файл — сотни КБ вместо 2–8 МБ с камеры: на
/// осмотре связь слабая, и заказчик ждёт каждый мегабайт.
const _shortSide = 1440;

const _quality = 80;

/// Сжатая копия снимка для отправки на сервер — `<path>.upload.jpg` рядом
/// с исходником; исходник не трогаем (VIN распознаётся по полному кадру).
/// Поворот по EXIF вшивается в пиксели, EXIF (с GPS) не сохраняется.
///
/// Сжатие ускоряет отправку, но не условие её: при любом сбое — исходный
/// путь, бекенд примет и его (до 10 МБ).
Future<String> compressForUpload(String path) async {
  try {
    final out = await FlutterImageCompress.compressAndGetFile(
      path,
      '$path.upload.jpg',
      minWidth: _shortSide,
      minHeight: _shortSide,
      quality: _quality,
      autoCorrectionAngle: true,
      keepExif: false,
    );
    return out?.path ?? path;
  } catch (_) {
    return path;
  }
}

/// Отправить [path] сжатым: [send] получает путь к файлу для формы.
/// Сжатая копия удаляется после отправки, удачной или нет.
Future<T> withUploadCopy<T>(
  String path,
  Future<T> Function(String uploadPath) send,
) async {
  final upload = await compressForUpload(path);
  try {
    return await send(upload);
  } finally {
    if (upload != path) {
      try {
        await File(upload).delete();
      } catch (_) {}
    }
  }
}
