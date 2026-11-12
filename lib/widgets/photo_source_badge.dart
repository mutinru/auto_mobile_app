import 'package:flutter/material.dart';

import '../models/inspection_panel.dart';
import '../theme/app_colors.dart';

/// Дата съёмки «03.05.2025» из строки сервера («2025-05-03 14:03:22…»).
String? _takenDate(PanelPhoto photo, {bool short = false}) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(photo.takenAt ?? '');
  if (m == null) return null;
  final year = short ? m[1]!.substring(2) : m[1]!;
  return '${m[3]}.${m[2]}.$year';
}

/// Подпись снимка из галереи (ревью №33) — под кадром на весь экран;
/// null — снимок с камеры, подписывать нечего.
String? photoSourceCaption(PanelPhoto photo) {
  if (!photo.fromGallery) return null;
  final date = _takenDate(photo);
  if (date == null) return 'Из галереи · дата съёмки неизвестна';
  return photo.takenBeforeStart == true
      ? 'Из галереи · снято $date, раньше начала осмотра'
      : 'Из галереи · снято $date';
}

/// Пометка на плитке снимка из галереи: «Галерея» и дата съёмки. Снято
/// раньше осмотра — красным. Снимок с камеры — ничего.
class PhotoSourceBadge extends StatelessWidget {
  const PhotoSourceBadge({super.key, required this.photo});

  final PanelPhoto photo;

  @override
  Widget build(BuildContext context) {
    if (!photo.fromGallery) return const SizedBox.shrink();
    final early = photo.takenBeforeStart == true;
    final date = _takenDate(photo, short: true) ?? 'без даты';
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        color: early
            ? context.colors.statusDefect.withValues(alpha: 0.85)
            : Colors.black.withValues(alpha: 0.6),
        child: Text(
          'Галерея\n$date',
          textAlign: TextAlign.center,
          maxLines: 2,
          style: const TextStyle(
            fontSize: 9,
            height: 1.15,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
