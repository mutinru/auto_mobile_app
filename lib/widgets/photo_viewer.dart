import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'api_error.dart';
import 'confirm_sheet.dart';

/// Одно фото на весь экран: табличка VIN, одометр.
void openPhotoViewer(BuildContext context, String url) =>
    openPhotoGallery(context, [url]);

/// Фото на весь экран с листанием, начиная с [initialIndex]. С [onDelete]
/// — кнопка «Удалить» (исполнитель на идущем осмотре): после удаления
/// просмотр закрывается, деталь уже подменена ответом сервера.
void openPhotoGallery(
  BuildContext context,
  List<String> urls, {
  int initialIndex = 0,
  Future<void> Function(int index)? onDelete,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PhotoViewer(
        urls: urls,
        initialIndex: initialIndex,
        onDelete: onDelete,
      ),
    ),
  );
}

/// Фото на весь экран, с масштабированием и листанием: деталь в отчёте и
/// на осмотре, табличка VIN. Ссылки подписанные, Bearer не нужен.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({
    super.key,
    required this.urls,
    this.initialIndex = 0,
    this.onDelete,
  });

  final List<String> urls;
  final int initialIndex;
  final Future<void> Function(int index)? onDelete;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  bool _deleting = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final onDelete = widget.onDelete!;
    final confirmed = await showConfirmSheet(
      context,
      title: 'Удалить фото?',
      text: 'Снимок пропадёт из отчёта по этой детали.',
      confirmLabel: 'Удалить',
    );
    if (!confirmed || !mounted) return;

    setState(() => _deleting = true);
    try {
      await onDelete(_index);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonStyle = IconButton.styleFrom(
      backgroundColor: context.colors.bg1,
      foregroundColor: context.colors.text1,
    );
    return Scaffold(
      backgroundColor: context.colors.bg0,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _pages,
                itemCount: widget.urls.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => InteractiveViewer(
                  maxScale: 5,
                  child: Center(
                    child: Image.network(
                      widget.urls[i],
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
            ),
            Positioned(
              top: 12,
              left: 14,
              child: IconButton(
                tooltip: 'Закрыть',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 18),
                style: buttonStyle,
              ),
            ),
            if (widget.urls.length > 1)
              Positioned(
                top: 22,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Text(
                    '${_index + 1} / ${widget.urls.length}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.monoFamily,
                      fontSize: 12.5,
                      color: context.colors.text2,
                    ),
                  ),
                ),
              ),
            if (widget.onDelete != null)
              Positioned(
                top: 12,
                right: 14,
                child: IconButton(
                  tooltip: 'Удалить фото',
                  onPressed: _deleting ? null : _delete,
                  icon: _deleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline, size: 18),
                  style: buttonStyle,
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
