import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Дата съёмки снимка из галереи (ревью №33) — из EXIF, до сжатия: сжатая
/// копия уходит на сервер без EXIF (`compressForUpload`), а отчёт помечает
/// фото из галереи датой съёмки. Формат — как у сервера:
/// «2025-05-03 14:03:22» и смещение «+03:00», если телефон его записал.
/// Не JPEG, нет даты, любой сбой — null («дата неизвестна»).
Future<String?> photoTakenAt(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    // разбор — в отдельном изоляте: снимок бывает на десяток мегабайт
    return await Isolate.run(() => takenAtFromJpeg(bytes));
  } catch (_) {
    return null;
  }
}

/// [photoTakenAt] для уже прочитанных байтов.
String? takenAtFromJpeg(List<int> bytes) {
  final exif = img.decodeJpgExif(
    bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
  );
  final raw = exif?.exifIfd[0x9003]?.toString().trim();
  final m = RegExp(
    r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}:\d{2}:\d{2})',
  ).firstMatch(raw ?? '');
  if (m == null) return null;
  final offset = exif?.exifIfd[0x9011]?.toString().trim() ?? '';
  final zone = RegExp(r'^[+-]\d{2}:\d{2}$').hasMatch(offset) ? offset : '';
  return '${m[1]}-${m[2]}-${m[3]} ${m[4]}$zone';
}
