import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

void openPhotoViewer(BuildContext context, String url) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => PhotoViewer(url: url)));
}

/// Фото на весь экран, с масштабированием: деталь в отчёте, табличка VIN.
/// Ссылка — подписанная, Bearer не нужен.
class PhotoViewer extends StatelessWidget {
  const PhotoViewer({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg0,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.broken_image_outlined,
                      size: 32,
                      color: context.colors.text3,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 14,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: context.colors.bg1,
                  foregroundColor: context.colors.text1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «VIN ··· 100111 · фото таблички» — по тапу снимок на весь экран.
class VinPlateRow extends StatelessWidget {
  const VinPlateRow({
    super.key,
    required this.vinMasked,
    required this.photoUrl,
  });

  final String vinMasked;
  final String photoUrl;

  @override
  Widget build(BuildContext context) => PhotoFactRow(
    value: 'VIN $vinMasked',
    caption: 'фото таблички',
    photoUrl: photoUrl,
  );
}

/// Факт, снятый на осмотре, и его фото: «148 000 км · фото одометра».
/// По тапу снимок на весь экран; без фото (старые осмотры) — просто факт.
class PhotoFactRow extends StatelessWidget {
  const PhotoFactRow({
    super.key,
    required this.value,
    required this.caption,
    required this.photoUrl,
  });

  final String value;
  final String caption;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    return InkWell(
      onTap: url == null ? null : () => openPhotoViewer(context, url),
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: context.colors.bg1,
          border: Border.all(color: context.colors.line),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Icon(
              url == null ? Icons.speed_outlined : Icons.photo_camera_outlined,
              size: 17,
              color: context.colors.text2,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: AppTheme.monoFamily,
                  fontSize: 12.5,
                  color: context.colors.text1,
                ),
              ),
            ),
            if (url != null) ...[
              Text(
                caption,
                style: TextStyle(fontSize: 12, color: context.colors.text3),
              ),
              Icon(Icons.chevron_right, size: 16, color: context.colors.text3),
            ],
          ],
        ),
      ),
    );
  }
}
